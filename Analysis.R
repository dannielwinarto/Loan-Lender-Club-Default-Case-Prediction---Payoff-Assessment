# Reference
# http://www.r-bloggers.com/r-and-postgresql-using-rpostgresql-and-sqldf/
# https://www.youtube.com/watch?v=90j5rX6iSGI

# For any question please feel free to contact me at
# 206-372-0352
# dannielwinarto@gmail.com


setwd("C:/Users/dan_9/Desktop/COURSERA + SELF STUDY/payoff") # directory of the folder in my laptop, should be different on your computer

## You can just load the file working.Rdata to skip the running process of data mining, data cleaning, and building model process

# load("working.Rdata")
# save.image("working.Rdata")

library(DBI)
library(RPostgreSQL)
library(dplyr)
library(lubridate)
library(stringr)

# To connect into amazon Web service
con =  dbConnect(PostgreSQL(), dbname = "intern",
                host = "payoff-showtime.ctranyfsb6o1.us-east-1.rds.amazonaws.com", port = 5432,
                user = "payoff_intern", password = 'reallysecure' )

data2007_2011 = dbGetQuery(con, "SELECT * from lending_club_2007_2011 ")
data2012_2013 = dbGetQuery(con, "SELECT * from lending_club_2012_2013 ")
data2014 = dbGetQuery(con, "SELECT * from lending_club_2014 ")
data2015 = dbGetQuery(con, "SELECT * from lending_club_2015 ")

# disconnect the existing connection
dbDisconnect(con)

# combining all 4 tables into variable called data
data = rbind(data2007_2011,data2012_2013,data2014,data2015)
glimpse(data)

# Set A
# Below are a series of business questions regarding the Lending Club dataset. We need
# you to determine key performance indicators/metrics (KPIs) that can answer these needs.

# 1. What is the monthly total loan volume by dollars and by average loan size?
# analysis: two columns are needed for this analysis loan_amnt and issue_d

# first we need to inspect if theres missing element on the columns of our analysis
unique(data$issue_d) # we found there are records with missing value
which(data$issue_d == "") # 39787 , is the row number of that missing value

# inspecting loan_amnt columns
which(is.na(data$loan_amnt)) # 1 row is empty, and row number is 39787
# 1 record is NA, we can delete this observation
data = data[-39787,]

# creating temporary name name to convert issue date from sring to time 
temp = dmy(paste0("1-",data$issue_d))
data$issue_d = temp

data$issue_d_month = month(data$issue_d)
data$issue_d_year = year(data$issue_d)

# SET A Question 1 ANSWER:
total_loan_volume_by_month  = data %>% group_by(issue_d_month) %>% summarise(total_loan = sum(loan_amnt)) 
average_loan_volume_by_month = data %>% group_by(issue_d_month) %>% summarise(average_loan = mean(loan_amnt))

total_loan_volume_by_month_year  = data %>% group_by(issue_d_month, issue_d_year) %>% summarise(total_loan = sum(loan_amnt)) 
average_loan_volume_by_month_year = data %>% group_by(issue_d_month,issue_d_year) %>% summarise(average_loan = mean(loan_amnt))



##########################
# 2. What are the default rates by Loan Grade?
# analysis: 
# http://www.investopedia.com/terms/d/defaultrate.asp
# two definitions of default rate: 
# 1. The rate of borrowers who fail to remain current on their loans. It is a critical piece of information used by lenders to determine their risk exposure and economists to evaluate the health of the overall economy.
# 2. The interest rate charged to a borrower when payments on a revolving line of credit are overdue. This higher rate is applied to outstanding balances in arrears in addition to the regular interest charges for the debt.

# checking on missing values
table(data$grade) #no missing values
table(data$loan_status) #no missing values

# adding new variable int_rate_in_percent since int_rate is in string format
data$int_rate_in_percent = as.numeric(gsub("%","",data$int_rate))

# SET A Question 2 ANSWER:
default_rate_by_loan_grade_definition_1 = data %>% group_by(grade) %>% summarise(default_rate = sum(loan_status == "Default")/n(), total_member_each_grade = n())

default_rate_by_loan_grade_definition_2 = data %>% filter(loan_status == "Default") %>% group_by(grade) %>% 
  summarise(average_interest_rate_in_percent = mean(int_rate_in_percent), total_default_cases = n())

interest_rate_by_loan_grade = data %>% group_by(grade) %>% summarise(average_interest_rate_in_percent = mean(int_rate_in_percent))



##########################
# 3. Are we charging an appropriate rate for risk?

# In my opinion: Yes, we are charging appropriate rate for the risk that calculated. As I previously stated, Members in group G has the highest probability to be default, thus it is necessary for the company to set highest interest rate for this group. Although I agree that group G deserve to have the highest interest rate, Im not sure if 25.6 percent interest rate is reasonable number for group G. I personally think 25.6 % is way too high.


  
##########################
# 4. What are the predictors of default rate?
# we need to build a model, in this case logistic regressioin model, to see which predictor are statistically significant, and also test it to the testing data,
# the composition is 80 % training data, 20 % testing data

data$grade = as.factor(data$grade)
data$term = as.factor(data$term)
data$issue_d_year = as.factor(data$issue_d_year)
data$application_type = as.factor(data$application_type)
data$home_ownership = as.factor(data$home_ownership)
data$loan_status = as.factor(data$loan_status)
data$purpose = as.factor(data$purpose)
data$verification_status = as.factor(data$verification_status)

# mutate additional column for default and non default code 
# 0 = not default
# 1 = default
data = data %>% mutate(loan_status_code = ifelse(loan_status == "Default", 1, 0))

# I assume that NAs in month_since_(something) variables means that the member has no previous record regarding that particular situation, so I changed NAs into 120 months(10 years)
data$mths_since_last_delinq[is.na(data$mths_since_last_delinq)] = 120 
data$mths_since_last_major_derog[is.na(data$mths_since_last_major_derog)] = 120 
data$mths_since_last_record[is.na(data$mths_since_last_record)] = 120 
data$mths_since_rcnt_il[is.na(data$mths_since_rcnt_il)] = 120 
data$mths_since_recent_bc[is.na(data$mths_since_recent_bc)] = 120 
data$mths_since_recent_bc_dlq[is.na(data$mths_since_recent_bc_dlq)] = 120 
data$mths_since_recent_inq[is.na(data$mths_since_recent_inq)] = 120 
data$mths_since_recent_revol_delinq[is.na(data$mths_since_recent_revol_delinq)] = 120 


# list of column that going to be used for logistic regression analysis: 
# loan_status_code, funded_amnt_inv, installment, int_rate_in_percent,total_acc, dti, revol_bal, annual_inc, total_rec_late_fee, grade, total_pymnt, total_pymnt_inv, total_rec_prncp, purpose, mths_since_last_delinq,mths_since_last_major_derog,mths_since_last_record, mths_since_rcnt_il,mths_since_recent_bc,mths_since_recent_bc_dlq,mths_since_recent_inq,mths_since_recent_revol_delinq

data_for_logist_reg = select(data, loan_status_code, funded_amnt_inv, installment,
                             int_rate_in_percent,total_acc,
                             dti, revol_bal, annual_inc, total_rec_late_fee,
                             grade, total_pymnt, total_pymnt_inv, total_rec_prncp, purpose,
                             mths_since_last_delinq,mths_since_last_major_derog,mths_since_last_record,
                             mths_since_rcnt_il,mths_since_recent_bc,mths_since_recent_bc_dlq,
                             mths_since_recent_inq,mths_since_recent_revol_delinq)

# check for missing values in each column
temp  = data.frame(NULL)
for (i in 1:length(names(data_for_logist_reg))) {
  temp[i,1] = names(data_for_logist_reg)[i]
  temp[i,2] = sum(is.na(data_for_logist_reg[,i]))
}
# V1 V2
# 1                loan_status_code  0
# 2                 funded_amnt_inv  0
# 3                     installment  0
# 4             int_rate_in_percent  0
# 5                       total_acc 29
# 6                             dti  0
# 7                       revol_bal  0
# 8                      annual_inc  4
# 9              total_rec_late_fee  0
# 10                          grade  0
# 11                    total_pymnt  0
# 12                total_pymnt_inv  0
# 13                total_rec_prncp  0
# 14                        purpose  0
# 15         mths_since_last_delinq  0
# 16    mths_since_last_major_derog  0
# 17         mths_since_last_record  0
# 18             mths_since_rcnt_il  0
# 19           mths_since_recent_bc  0
# 20       mths_since_recent_bc_dlq  0
# 21          mths_since_recent_inq  0
# 22 mths_since_recent_revol_delinq  0

# we can just omit those 22 records for the sake of building logistic model 
data_for_logist_reg = na.omit(data_for_logist_reg)

# creating sampling index - 80 percent training, 20 percent testing
dim(data_for_logist_reg)[1]      # 887353
0.80*dim(data_for_logist_reg)[1] # 709882

set.seed(100)
index = sample(1:887378,709882)

training_data = data_for_logist_reg[index,] # 80 percent dataset
testing_data = data_for_logist_reg[-index,] # 20 percent dataset


logistic_model = glm(loan_status_code ~ .,
                  data = training_data, family = binomial)

summary(logistic_model)


# to test how well this model perform, we use testing data - 20% of dataset
logistic_model_pred_probs = predict(logistic_model, testing_data, type = "response" )

# this only gives us probability so we need to convert into direction, we use cutoff value of 0.2
model_pred_0_NotDefault_1_Default = rep("0", dim(testing_data)[1])
model_pred_0_NotDefault_1_Default[logistic_model_pred_probs >.2] = "1"

testing_0_NotDefault_1_Default = data_for_logist_reg[-index,1]

length(testing_0_NotDefault_1_Default)
length(model_pred_0_NotDefault_1_Default)

table(model_pred_0_NotDefault_1_Default,testing_0_NotDefault_1_Default)

mean(model_pred_0_NotDefault_1_Default != testing_0_NotDefault_1_Default)

# save.image("working.Rdata")




sum(data$loan_status == "Default")
