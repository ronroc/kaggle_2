require(data.table); require(lubridate); require(caret); require(sqldf); require(xgboost); require(sqldf);  require(Matrix)

train_raw <- fread(input = "D:\\kaggle\\HOMESITE\\Data\\train.csv", data.table = F)

response <- train_raw$QuoteConversion_Flag

response <- as.matrix(response)

train_raw$QuoteConversion_Flag <- NULL

train_raw$QuoteNumber <- NULL


test_raw <- fread(input = "D:\\kaggle\\HOMESITE\\Data\\test.csv", data.table = F)

id <- test_raw$QuoteNumber

test_raw$QuoteNumber <- NULL


tmp <- rbind(train_raw, test_raw)

tmp$Original_Quote_Date <- as.Date(tmp$Original_Quote_Date)

tmp$month <- as.integer(format(tmp$Original_Quote_Date, "%m"))

tmp$year <- as.integer(format(tmp$Original_Quote_Date, "%y"))

tmp$day <- weekdays(as.Date(tmp$Original_Quote_Date))

continous_field <- tmp$SalesField8

tmp$SalesField8 <- NULL

tmp$Original_Quote_Date <- NULL

tmp <- as.matrix(tmp)

# group data => create combinations of a given order

groupData <- function(xmat, degree)

  {
  
  require(foreach, quietly = T)
  
  # indices of combinations
  
  xind <- combn(1:ncol(xmat), degree)
  
  
  # storage structure for the result
  agx <- foreach(ii = 1:ncol(xind), .combine = cbind ) %do%
  {
    x <- xmat[,xind[1,ii]]
    for (jj in 2:nrow(xind))
    {
      x <- paste(x, xmat[,xind[jj,ii]], sep = "_")
    }
    x
  }
  colnames(agx) <- paste(paste("f", degree, sep = ""), 1:ncol(agx), sep = "_")
  return(agx)
}

gc()

double <- groupData(tmp, 2)

gc()

tmp_mat <- cbind(tmp, double)

write_csv(tmp_mat, file = gzfile("_double_.csv.gz"))

tmp_mat_train <- tmp_mat[1:260753 , ]

tmp_mat_test = tmp_mat[(260753+1):434589, ]

response_test = numeric()


# need tmp_mat_train, tmp_mat_test, response, response_test : remove everything

keep <- c("tmp_mat_train", "tmp_mat_test", "response", "response_test")

toremove <- setdiff(ls(), keep)

rm(list = c(toremove, "toremove"))



#function for forward stepwise logistic regression fitting to determine optimal features to encode

# using rm to keep elements needed rather than the other way


# FOR SPARSE MATRIX CREATION COLS SHOULD BE IN FACTORS

set.seed(508)

require(glmnet, quietly = T)

require(Matrix, quietly = T)

#initialize optimization metrics-----------------------------------------------------------------------------------------------

cv_max_auc = 0.5 #target minimum.... represents random guess

cv_fold_auc = numeric()

cv_train_auc = numeric()

#initialize feature holding-----------------------------------------------------------------------------------------------------

best_col = numeric()

num_features = numeric()

# big inefficient for loop that does everything -------------------------------------------------------------------------------

for(i in 1:ncol(tmp_mat_train)) 
  
{
  
  # add columns selected + iteration column
  
  colName = colnames(tmp_mat_train)[c(best_col, i)] 
  
  vars = as.data.frame(tmp_mat_train[,c(best_col, i)])
  
  colnames(vars) = colName
  
  #encode into sparse model               
  
  vars = sparse.model.matrix(~ . - 1, data = vars)                     
  
  #10 fold logistic regression w/ lasso reg ran to obtain max mean AUC on validation set
  
  for(j in 1:10) 
    
  {
    
    cv_train = cv.glmnet(x = vars, y = response[,1], family = "binomial", type.measure = "auc")
    
    cv_fold_auc[j] = max(cv_train$cvm)
    
  }
  
  cv_train_auc[i] = mean(cv_fold_auc)
  
  #reset cv fold auc
  
  cv_fold_auc = numeric()
  
  #determining if new column is useful.  if so, adding to the model and raising auc bar
  
  if(cv_train_auc[i] > cv_max_auc)
    
  {
    
    #for next iteration: know indecies of the columns to keep
    
    best_col = c(best_col, i)
    
    #store how many important features from the current set to plot against auc
    
    best_features = which(coef(cv_train, s = cv_train$lambda.min) > 0)
    
    num_features[i] = length(best_features)
    
    #raise auc bar
    
    cv_max_auc = cv_train_auc[i]
    
  }
  
  #live update
  
  for(k in 1)
    
  {
    
    print(cat('Feature Loop', i, 'complete.  Max validation AUC:', cv_max_auc, 'Number of features:', num_features[i]))
    
  }
  
}

print(best_col) 

tmp_mat_train = tmp_mat_train[,best_col]


train = tmp_mat_train[1:260753 ,  ]


test <- tmp_mat_train[(260753+1):434589, ]


dtrain <- xgb.DMatrix(data = train, label=response)


param <- list(objective           = "binary:logistic",
              
              booster = "gbtree",
              
              eval_metric = "auc",
              
              eta = 0.02, # 0.06, #0.01,
              
              max_depth = 7, #changed from default of 8
              
              subsample = 0.86, # 0.7
              
              colsample_bytree = 0.68, # 0.7
              
              num_parallel_tree = 2
              
              # alpha = 0.0001,
              
              # lambda = 1
              )


cl <- makeCluster(2); registerDoParallel(cl)


set.seed(11*28*15)


#cv <- xgb.cv(params = param, data = dtrain, 
             
#             nrounds = 1900, 
             
#             nfold = 4, 
             
#             showsd = T, 
             
#             maximize = F)


start <- Sys.time()


clf <- xgb.train(   params              = param,
                    
                    data                = dtrain,
                    
                    nrounds             = 1900,
                    
                    verbose             = 1,  #1
                    
                    #early.stop.round    = 150,
                    
                    #watchlist           = watchlist,
                    
                    maximize            = FALSE,
                    
                    nthread = 2)



pred <- predict(clf, (test))


submission <- data.frame(QuoteNumber = id, QuoteConversion_Flag = pred)


write_csv(submission, "D:\\kaggle\\HOMESITE\\submission\\11282015.csv")

total_time <- Sys.time() - start