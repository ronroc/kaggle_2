# seperate tmp into seperate df's for char, num, binary, dates -- manipulate -- combine

require(data.table); require(lubridate); require(caret); require(sqldf); require(xgboost); require(sqldf) 


train_raw <- fread(input = "D:\\kaggle\\HOMESITE\\Data\\train.csv", data.table = F)

response <- train_raw$QuoteConversion_Flag

train_raw$QuoteConversion_Flag <- NULL

train_raw$QuoteNumber <- NULL


test_raw <- fread(input = "D:\\kaggle\\HOMESITE\\Data\\test.csv", data.table = F)

id <- test_raw$QuoteNumber

test_raw$QuoteNumber <- NULL


tmp <- rbind(train_raw, test_raw)


feature.names <- names(tmp)[c(2:297)]


###########################################################################################


# THIS STEP NOT REQUIRED AS tmp df ARE SEPERATED

cat("assuming text variables are categorical & replacing them with numeric ids\n")

for (f in feature.names) {
  
  if (class(train_raw[[f]]) == "character") {
    
    levels <- unique(c(train_raw[[f]], test_raw[[f]]))
    
    train_raw[[f]] <- as.integer(factor(train_raw[[f]], levels=levels))
    
    test_raw[[f]]  <- as.integer(factor(test_raw[[f]],  levels=levels))
  }
}


#################################################################################################

#rm(train); rm(test)


# seperate into  character columns----------------------------------------------------------------------
  
  
char <- rep(0, ncol(tmp))

for( i in 1:ncol(tmp)){
  
  if(class(tmp[[i]]) == "character"){
    
    char[i] <- c(names(tmp)[i])
    
  }
}


char <- char[char != 0 ]

tmp_char <- tmp[, char]


##################################################################################################


# seperate column with date-----------------------------------------------------------------------


tmp_char$Original_Quote_Date <- as.Date(tmp_char$Original_Quote_Date)

tmp_date <- data.frame(tmp_char[, "Original_Quote_Date"])

tmp_char$Original_Quote_Date <- NULL

names(tmp_date) <- "Original_Quote_Date"


# work with date df first 

# basics - deep exploration needed for further feature creation

tmp_date$year <- year(tmp_date$Original_Quote_Date)

tmp_date$wday <- wday(tmp_date$Original_Quote_Date)

tmp_date$day <- day(tmp_date$Original_Quote_Date)

tmp_date$month <- month(tmp_date$Original_Quote_Date)

tmp_date$Original_Quote_Date <- NULL


# run a model by  removing date and without and check the difference

################################################################################################

# working with character data------------------------------------------------------------------
  
# check for Field 10 presence
  
# tmp_num$Field10 <- tmp_char$Field10
  
# tmp_char$Field10 <- NULL
  
  
#lapply(tmp_char, function(x) table(x))
  
# options : 1. dummify for large & small column nos and check model performance; 

# write codes fr both

#         : 2. can`t use length ...and other modifications since the columns here are used as 

#              indicators

#         : 3. check other ways for coding variables


# basics ---- convert into numeric and use 1,2,3 counts-------------------------------------------
  
# assuming text variables are categorical and replacing them with numeic ids
  
# for reconverting types of some columns use data from tmp and delete cols in tmp_char
  
  
  
  for(f in names(tmp_char)){
    
    levels <- unique(tmp_char[[f]])
    
    tmp_char[[f]] <- as.numeric(factor(tmp_char[[f]], levels = levels))
    
  }



# DUMMFYING ALL CHAR COLUMNS -- CHANGE THIS STEP IF NECESSARY


dummy_char = names(tmp_char)


################################################################################################


# apply condition here

# dummfying columns with length lesser than 7


dummy_char <- rep(0, ncol(tmp_char))


for( i in 1: ncol(tmp_char)){
  
  if(length(unique(tmp_char[[i]])) < 15) {
    
    dummy_char[i] <- c(names(tmp_char)[i])
  }
}


dummy_char <- dummy_char[ dummy_char != 0 ]


################################################################################################


# creation of dummy variables---------------------------------------------------------------------
  
  
tmp_char_dummy <- tmp_char[ , dummy_char]

len = length(names(tmp_char_dummy))



for(i in 1:len){
  
  print(paste0(( i / len) * 100, "%"))
  
  levels <- unique(tmp_char_dummy[[i]])
  
  tmp_char_dummy[, i] <- factor(tmp_char_dummy[, i], levels = levels)
  
}


gc()


dummies <- dummyVars( ~., data = tmp_char_dummy)

gc()


tmp_char_dummy <- predict(dummies, newdata = tmp_char_dummy)

tmp_char_dummy <- data.frame(tmp_char_dummy)

dim(tmp_char_dummy)


####################################################################################################


#seperate columns with binary components-----------------------------------------------------------
  
  
binary <- rep(0, ncol(tmp))

for( i in 1:ncol(tmp)){
  
  if(length(table(tmp[[i]])) == 2){
    
    binary[i] <- c(names(tmp)[i])
    
  }
}



binary <- binary[binary != 0]

tmp_binary <- tmp[, binary]



# Numerical columns--------------------------------------------------------------------------------
  
  
tmp_num <- tmp[ , !(names(tmp) %in% c(char, binary))]

# difference from mean

# standardisation


#change application methods after data deep dive

# 11152015 not changing any of default values


###################################################################################################


# since these columns are now numeric count(1,2,3)

# run model with and without to check effect of these extra vars


# include cols from numeric df


tmp_factors = tmp_char

len = length(names(tmp_factors))

for (i in 1:len) {
  
  print(paste0( i / (len) *100, "%"))
  
  levels <- unique(tmp_factors[[i]])
  
  tmp_factors[ , i] <- factor(tmp_factors[ , i], levels = levels)
  
}

#Important step ^^^^

#############################################################################################################

# 2 way count

nms <- combn(names(tmp_factors), 2)

dim(nms)

nms_df <- data.frame(nms) 

len = length(names(nms_df))


for (i in 1:len) {
  
  nms_df[, i] <- as.character(nms_df[, i])
  
}


tmp_count <- data.frame(id = 1:dim(tmp)[1])

for(i in 1:dim(nms_df)[2]){
  
  
  #new df 
  
  print(((i / dim(nms_df)[2]) * 100 ))
  
  tmp_count[, paste(i, "_two", sep="")] <- my.f2cnt(th2 = tmp, 
                                                    
                                                    vn1 = nms_df[1,i], 
                                                    
                                                    vn2 = nms_df[2,i] )
  
}


###############################################################################################################


#3 way count

nms <- combn(names(tmp_factors), 3)

dim(nms)

nms_df <- data.frame(nms);

len = length(names(nms_df))


for (i in 1:len) {
  
  print(paste0(( i / len) *100, "%"))
  
  nms_df[, i] <- as.character(nms_df[, i])
  
}


for(i in 1:dim(nms_df)[2]){
  
  #new df 
  
  print((i / dim(nms_df)[2]) * 100)
  
  tmp_count[, paste(i, "_three", sep="")] <- my.f3cnt(th2 = tmp, 
                                                      
                                                      vn1 = nms_df[1,i], 
                                                      
                                                      vn2 = nms_df[2,i], 
                                                      
                                                      vn3 = nms_df[3,i])
  
}


##############################################################################################################


#one way count

len = dim(tmp_factors)[2]

for(i in 1:len){
  
  
  print((i / len) * 100 )
  
  tmp_factors$x <- tmp_factors[, i]
  
  sum1 <- sqldf("select x, count(1) as cnt
                
                from tmp_factors  group by 1 ")
  
  tmp1 <- sqldf("select cnt from tmp_factors a left join sum1 b on a.x=b.x")
  
  tmp_count[, paste(names(tmp_factors)[i], "_one", sep="")] <- tmp1$cnt
  
}  


################################################################################################

# list all edited df here

# tmp_char

# tmp_num

# tmp_binary

# tmp_char_dummy

# tmp_count

# tmp_date


# converting all cols of tmp_char to numeric 


tmp_new <- cbind.data.frame(tmp_char, tmp_num, tmp_binary, tmp_char_dummy, tmp_count,
                            
                            tmp_date
                            )

# edit : can remove further edited cols


train <- tmp_new[c(1:260753), ]

test <- tmp_new[c(260754:434589), ]

gc()


train[is.na(train)] <- 0

test[is.na(test)] <- 0

gc()

# write rm methods also

# or select and delete by changing to grid 

# more efficient








###################################################################################################

imp <- read.xlsx("feature_importance.xlsx", sheetIndex = 1, stringsAsFactors=FALSE)

top_25 <- imp$Feature[1:25]

tmp_25 <- tmp[, top_25]

lapply(tmp_25, function(x) unique(x))

lapply(tmp_25_result , function(x) sum(is.na(x)))


# first convert all characte to numeric

for (f in top_25) {
  
  if (class(tmp_25[[f]])=="character") {
    
    levels <- unique(tmp_25[[f]])
    
    tmp_25[[f]] <- as.integer(factor(tmp_25[[f]], levels=levels))
    
  }
}


###################################################################################################

# preprocess test---------------------------------------------------------------------------------

# method = knnImpute

iris_miss_1 <- iris[, -5]

iris_miss_1[1,1] <- NA

pp_1_test <- preProcess(iris_miss_1, method = "knnImpute")

set.seed(1)

test_1_result <- predict(pp_1_test, iris_miss_1)


# method = BagImpute

iris_miss_2 <- iris[, -5]

iris_miss_2[1,1] <- NA

pp_2_test <- preProcess(iris_miss_2, method = "bagImpute")

set.seed(1)

test_2_result <- predict(pp_2_test, iris_miss_2)

###################################################################################################


#knnImpute high data size

tmp_25_test = preProcess(tmp_25, method = "bagImpute")

set.seed(11212015)

tmp_25_result <- predict(tmp_25_test, tmp_25)

head(tmp_25_result)

###################################################################################################


