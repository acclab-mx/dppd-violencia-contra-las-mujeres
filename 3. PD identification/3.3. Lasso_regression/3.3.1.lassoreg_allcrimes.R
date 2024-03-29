rm(list=ls())

# Paquetes
library(readr)
library(dplyr)
library(tidyverse)
library(glmnet)
library(caret)
library(ggplot2)
library(repr)

#### Identificar desviaciones positivas con regresi�n LASSO ####

#### Delitos de todos los niveles de severidad ####

# Cargar la base de datos creada en el script 2.1.performance_measure
base <- read_csv("baseageb.csv")

# Especificar las variables que son factores
base <- transform(base, edomex=as.factor(edomex), cluster=as.factor(cluster))

# Eliminar los valores perdidos
base <- na.omit(base)

# Seleccionar las variables que utilizaremos
base <- base %>% 
  dplyr::select( CVEGEO, 
                 allcrimes_log, 
                 cluster,
                 POBTOT, 
                 area_agebkm, 
                 P_0A14, 
                 P_15A24, 
                 P_25A59, 
                 P_60YMAS, 
                 REL_H_M, 
                 PEA, 
                 HOGFEM, 
                 PRES2015, 
                 bienestar_socioeco, 
                 edomex, 
                 total_viajes, 
                 areaverde_por, 
                 comercio_km2, 
                 serv_financieros_km2, 
                 serv_educativos_km2, 
                 serv_salud_km2, 
                 serv_entretenimiento_km2, 
                 serv_preparacionalimentos_km2, 
                 serv_personales_km2, 
                 viasprimarias_km2, 
                 viassecundarias_km2, 
                 distanciamintransporte_km, 
                 paradastrolebus_km2, 
                 paradasrtp_km2, 
                 paradassitis_km2, 
                 sinpavimento_por, 
                 ambulantaje_por)

#### Mejor modelo por cluster ####

#### 1) Cluster 1 ####

# Separar la base por clusters
list1 <- split(base, base$cluster)
list1
list1$"1"
clus_1<-list1$"1"

# Crear una base con el identificador de las AGEBS y otra con la variable dependiente y las independientes del modelo
CVEGEO <- clus_1[1]
clus_1 <- clus_1[-1]
clus_1 <- clus_1 %>% 
  dplyr::select(-cluster)

# Crear matrices de "x" (variables independientes) y "y" (variable dependiente)
x <- model.matrix(allcrimes_log~., clus_1)[,-1]
y <- clus_1 %>% 
  dplyr::select(allcrimes_log) %>% 
  unlist() %>% 
  as.numeric()

# Dividir las observaciones en entrenamiento y de prueba 
set.seed(123)

train <-  clus_1 %>% 
  sample_frac(0.5)

test <- clus_1 %>% 
  setdiff(train)

x_train <- model.matrix(allcrimes_log~., train)[,-1]
x_test <- model.matrix(allcrimes_log~., test)[,-1]

y_train <- train %>% 
  dplyr::select(allcrimes_log) %>% 
  unlist() %>% 
  as.numeric()

y_test <- test %>% 
  dplyr::select(allcrimes_log) %>% 
  unlist() %>% 
  as.numeric()

# Encontrar la mejor lambda usando validaci�n cruzada (cv) en los datos de entrenamiento
set.seed(123)
cv.out = cv.glmnet(x_train, y_train, alpha=1)
plot(cv.out)

bestlam= cv.out$lambda.min
bestlam

# Predecir en los datos de prueba
lasso_pred= predict(cv.out, s= bestlam, newx= x_test)
mean((lasso_pred - y_test)^2)

# Correr el modelo LASSO en todos los datos
out = glmnet(x, y, alpha= 1, lambda = bestlam)
lasso_coef = predict(out, type= "coefficients", s= bestlam)

# Obtener los coeficientes de las variables seleccionadas
coef(out, s= bestlam)

# Predecir con lasso en todos los datos
predict <- predict(out, s = bestlam, newx = x)

# Calcular RMSE y R2 para el modelo 
data.frame(
  RMSE = RMSE(predict, clus_1$allcrimes_log),
  Rsquare = R2(predict, clus_1$allcrimes_log)
)

# Variables m�s importantes
varimp <- varImp(out, lambda = bestlam)
arrange(varimp, -Overall)

# Residuos del modelo
data <- cbind(CVEGEO, clus_1, predict) 
data <- data %>% 
  mutate(residuals = predict- allcrimes_log) %>% 
  arrange(-residuals)
hist(data$residuals)

# Encontrar las desviaciones positivas (PDS)
q1 = quantile(data$residuals)[2]
q3 = quantile(data$residuals)[4]
iqr = q3 - q1 
valmax = (iqr * 1.5) + q3
valmax
pd <- which(data$residuals > valmax)
data$CVEGEO[as.integer(pd)]

# Crear una base con los PDs
PD_allcrimes_c1 <- data %>% 
  filter(residuals >valmax) %>% 
  dplyr::select(CVEGEO, residuals)

PD_allcrimes_c1 <- left_join(PD_allcrimes_c1, base[c("CVEGEO", "cluster")], by = "CVEGEO")

#### 2) Cluster 2 ####

# Seleccionar las observaciones del cluster 2
clus_2<-list1$"2"
CVEGEO <- clus_2[1]
clus_2 <- clus_2[-1]
clus_2 <- clus_2 %>% 
  dplyr::select(-cluster)

# Crear matrices de x (variables independientes) y y (variable dependiente)
x <- model.matrix(allcrimes_log~., clus_2)[,-1]
y <- clus_2 %>% 
  dplyr::select(allcrimes_log) %>% 
  unlist() %>% 
  as.numeric()

# Dividir las observaciones en entrenamiento y de prueba
set.seed(123)
train <-  clus_2 %>% 
  sample_frac(0.5)
test <- clus_2 %>% 
  setdiff(train)
x_train <- model.matrix(allcrimes_log~., train)[,-1]
x_test <- model.matrix(allcrimes_log~., test)[,-1]

y_train <- train %>% 
  dplyr::select(allcrimes_log) %>% 
  unlist() %>% 
  as.numeric()

y_test <- test %>% 
  dplyr::select(allcrimes_log) %>% 
  unlist() %>% 
  as.numeric()

# Encontrar la mejor lambda
set.seed(123)
cv.out = cv.glmnet(x_train, y_train, alpha=1)
plot(cv.out)

bestlam= cv.out$lambda.min
bestlam

# Predecir en los datos de prueba
lasso_pred= predict(cv.out, s= bestlam, newx= x_test)
mean((lasso_pred - y_test)^2)

# Correr el modelo LASSO para todos los datos
out = glmnet(x, y, alpha= 1, lambda = bestlam)
lasso_coef = predict(out, type= "coefficients", s= bestlam)

# Obtener los coeficientes de las variables seleccionadas
coef(out, s= bestlam)

# Predecir con lasso en todos los datos
predict <- predict(out, s = bestlam, newx = x)

# Calcular RMSE y R2
data.frame(
  RMSE = RMSE(predict, clus_2$allcrimes_log),
  Rsquare = R2(predict, clus_2$allcrimes_log)
)

# Variables m�s importantes
varimp <- varImp(out, lambda = bestlam)
arrange(varimp, -Overall)

# Calcular los residuos 
data <- cbind(CVEGEO, clus_2, predict) 
data <- data %>% 
  mutate(residuals = predict- allcrimes_log) %>% 
  arrange(-residuals)

hist(data$residuals)

# Encontrar los PDs
q1 = quantile(data$residuals)[2]
q3 = quantile(data$residuals)[4]
iqr = q3 - q1 
valmax = (iqr * 1.5) + q3
valmax
pd <- which(data$residuals > valmax)
data$CVEGEO[as.integer(pd)]

# Crear una base para guardar los PDs
PD_allcrimes_c2 <- data %>% 
  filter(residuals >valmax) %>% 
  dplyr::select(CVEGEO, residuals)

PD_allcrimes_c2 <- left_join(PD_allcrimes_c2, base[c("CVEGEO", "cluster")], by = "CVEGEO")

#### 3) Cluter 2 #####

# Seleccionar las observaciones del cluster 3
clus_3<-list1$"3"
CVEGEO <- clus_3[1]
clus_3 <- clus_3[-1]
clus_3 <- clus_3 %>% 
  dplyr::select(-cluster)

# Crear matrices de x (variables independientes) y y (variable dependiente)
x <- model.matrix(allcrimes_log~., clus_3)[,-1]
y <- clus_3 %>% 
  dplyr::select(allcrimes_log) %>% 
  unlist() %>% 
  as.numeric()

# Dividir las observaciones en entrenamiento y de prueba 
set.seed(123)
train <-  clus_3 %>% 
  sample_frac(0.5)
test <- clus_3 %>% 
  setdiff(train)
x_train <- model.matrix(allcrimes_log~., train)[,-1]
x_test <- model.matrix(allcrimes_log~., test)[,-1]

y_train <- train %>% 
  dplyr::select(allcrimes_log) %>% 
  unlist() %>% 
  as.numeric()

y_test <- test %>% 
  dplyr::select(allcrimes_log) %>% 
  unlist() %>% 
  as.numeric()

# Encontrar la mejor lambda
set.seed(123)
cv.out = cv.glmnet(x_train, y_train, alpha=1)
plot(cv.out)
bestlam= cv.out$lambda.min
bestlam

# Predecir en los datos de prueba
lasso_pred= predict(cv.out, s= bestlam, newx= x_test)
mean((lasso_pred - y_test)^2)

# Correr el modelo LASSO para todos los datos
out = glmnet(x, y, alpha = 1, lambda = bestlam)
lasso_coef = predict(out, type= "coefficients", s= bestlam)

# Obtener los coeficientes de las variables seleccionadas
coef(out, s= bestlam)

# Calcular los valores predichos
predict <- predict(out, s = bestlam, newx = x)

# Calcluar RMSE y R2
data.frame(
  RMSE = RMSE(predict, clus_3$allcrimes_log),
  Rsquare = R2(predict, clus_3$allcrimes_log)
)

# Variables m�s importantes
varimp <- varImp(out, lambda = bestlam)
arrange(varimp, -Overall)

# Calcular los residuos
data <- cbind(CVEGEO, clus_3, predict)
data <- data %>% 
  mutate(residuals = predict- allcrimes_log) %>% 
  arrange(-residuals)

hist(data$residuals)

# Encontrar los PDs
q1 = quantile(data$residuals)[2]
q3 = quantile(data$residuals)[4]
iqr = q3 - q1 
valmax = (iqr * 1.5) + q3
valmax
pd <- which(data$residuals > valmax)
data$CVEGEO[as.integer(pd)]

# Guardar los PDs
PD_allcrimes_c3 <- data %>% 
  filter(residuals >valmax) %>% 
  dplyr::select(CVEGEO,residuals)

PD_allcrimes_c3 <- left_join(PD_allcrimes_c3, base[c("CVEGEO", "cluster")], by = "CVEGEO")

# Crear una sola base de resultados y guardarla 
PD_allcrimes_lasso <- bind_rows(PD_allcrimes_c1, PD_allcrimes_c2, PD_allcrimes_c3)

PD_allcrimes_lasso <- PD_allcrimes_lasso %>% 
  mutate(model = "lasso",
         result_var = "allcrimes_log")

write.csv(PD_allcrimes_lasso, "pd_allcrimes_lasso.csv", row.names = F)

