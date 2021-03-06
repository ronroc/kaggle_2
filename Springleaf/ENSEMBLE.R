rm(list = ls())

library(doParallel)

cl <- makeCluster(2)

registerDoParallel(cl)

library(xgboost)

library(readr); require(caret); require(caretEnsemble)


train <- read_csv("D:/kaggle/Springleaf/DATA/CSV/train.csv")


train$ID <- train_ID 

test <- read_csv("D:/kaggle/Springleaf/DATA/CSV/test.csv")

test_ID <- test$ID

train <- train[,-1]

test <- test[,-1]

train.unique.count=lapply(train, function(x) length(unique(x)))

train.unique.count_1=unlist(train.unique.count[unlist(train.unique.count)==1])

train.unique.count_2=unlist(train.unique.count[unlist(train.unique.count)==2])

train.unique.count_2=train.unique.count_2[-which(names(train.unique.count_2)=='target')]

delete_const=names(train.unique.count_1)

delete_NA56=names(which(unlist(lapply(train[,(names(train) %in% names
                                              (train.unique.count_2))], function(x) max
                                      (table(x,useNA='always'))))==145175))

delete_NA89=names(which(unlist(lapply(train[,(names(train) %in% names
                                              (train.unique.count_2))], function(x) max
                                      (table(x,useNA='always'))))==145142))

delete_NA918=names(which(unlist(lapply(train[,(names(train) %in% names
                                               (train.unique.count_2))], function(x) max
                                       (table(x,useNA='always'))))==144313))

#VARS to delete
#safe to remove VARS with 56, 89 and 918 NA's as they are covered by other VARS
print(length(c(delete_const,delete_NA56,delete_NA89,delete_NA918)))

train=train[,!(names(train) %in% c(delete_const,delete_NA56,delete_NA89,delete_NA918))]

test=test[,!(names(test) %in% c(delete_const,delete_NA56,delete_NA89,delete_NA918))]

gc()

feature.names <- names(train)[1:(ncol(train)) - 1]

for (f in feature.names) {
  
  if (class(train[[f]])=="character") {
    
    levels <- unique(c(train[[f]], test[[f]]))
    
    train[[f]] <- as.integer(factor(train[[f]], levels=levels))
    
    test[[f]]  <- as.integer(factor(test[[f]],  levels=levels))
  }
}

cat("replacing missing values with -1\n")
train[is.na(train)] <- -1

test[is.na(test)]   <- -1

gc()

train_new <- data.frame(lapply(train, function(x) as.numeric(x)))

test_new <- data.frame(lapply(test, function(x) as.numeric(x)))

library('caret')

library('mlbench')

library('pROC')

inTrain <- createDataPartition(y = train$target, p = .75, list = FALSE)

training <- train[inTrain, ]

testing <- train[-inTrain,]

my_control <- trainControl(
  
  method='cv',
  
  number=2,
  
  savePredictions=TRUE,
  
  classProbs=TRUE,
  
  index=createResample(train$target, 2),
  
  summaryFunction=twoClassSummary,
  
  allowParallel = T,
  
  verboseIter = T
)

library('caretEnsemble')

  treebagFuncs$summary = twoClassSummary

refcontrol = rfeControl(functions = treebagFuncs, 
                        
                        method="cv", 
                        
                        number=3,
                        

                        
                        p=0.75,
                        
                        verbose=TRUE, allowParallel = T)

refResult = rfe(train[,-ncol(train)], 
                
                as.factor(train$target), 
                
                sizes=seq(500,1500,100), 
                
                rfeControl=refcontrol,
                
                metric="ROC",
                
                maximize=TRUE,
                
                verbose=TRUE)

# summarize the results
print(refResult)
# list the chosen features
predictors(refResult)


model_list <- caretList(
  
  target ~., data=training,
  
  trControl=my_control,
  
  metric = 'ROC', 
  
  methodList=c('gbm', 'xgbTree')
)

p <- as.data.frame(predict(model_list, newdata=head(testing)))

print(p)

library('mlbench')

library('randomForest')

library('nnet')

model_list_big <- caretList(
  
  target ~., data=training,
  
  trControl=my_control,
  
  metric='ROC',
  
  methodList=c('gbm', 'xgbTree'),
  
  tuneList=list(
    
    rf1=caretModelSpec(method='gbm'),
    
    rf2=caretModelSpec(method='xgbTree', preProcess='pca'),
    
    nn=caretModelSpec(method='nnet', tuneLength=2, trace=FALSE)
  )
)

xyplot(resamples(model_list))

modelCor(resamples(model_list))

greedy_ensemble <- caretEnsemble(model_list)

summary(greedy_ensemble)

library('caTools')

model_preds <- lapply(model_list, predict, newdata=testing, type='prob')

model_preds <- lapply(model_preds, function(x) x[,'M'])

model_preds <- data.frame(model_preds)

ens_preds <- predict(greedy_ensemble, newdata=testing)

model_preds$ensemble <- ens_preds

colAUC(model_preds, testing$Class)

xgb_ensemble <- caretStack(
  
  model_list, 
  
  method='xgbTree',
  
  metric='ROC',
  
  trControl=trainControl(
    
    method='cv',
    
    number=3,
    
    savePredictions=TRUE,
    
    classProbs=TRUE,
    
    summaryFunction=twoClassSummary
  )
  
)

model_preds2 <- model_preds

model_preds2$ensemble <- predict(xgb_ensemble, newdata=testing, type='prob')$M

CF <- coef(xgb_ensemble$ens_model$finalModel)[-1]

colAUC(model_preds2, testing$target)

library('gbm')

gbm_ensemble <- caretStack(
  
  model_list, 
  
  method='xgbTree',
  
  verbose=T,
  
  metric='ROC',
  
  
  trControl=trainControl(
    
    method='cv',
    
    number=3,
    
    savePredictions=TRUE,
    
    classProbs=TRUE,
    
    summaryFunction=twoClassSummary
  )
)

model_preds3 <- model_preds

model_preds3$ensemble <- predict(xgb_ensemble, newdata=testing, type='prob')$M

colAUC(model_preds3, testing$target)