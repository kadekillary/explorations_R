dir.create("~/Desktop/explorations_R/keras_tensor/downloads/jena_climate", recursive = TRUE)
download.file("https://s3.amazonaws.com/keras-datasets/jena_climate_2009_2016.csv.zip", "~/Desktop/explorations_R/keras_tensor/downloads/jena_climate/jena_climate_2009_2016.csv.zip")
unzip("~/Desktop/explorations_R/keras_tensor/downloads/jena_climate/jena_climate_2009_2016.csv.zip", exdir = "~/Desktop/explorations_R/keras_tensor/downloads/jena_climate")

library(tibble)
library(readr)
library(keras)

data_dir <- "./downloads/jena_climate"
fname <- file.path(data_dir, "jena_climate_2009_2016.csv")
data <- read_csv(fname)

glimpse(data)

library(ggplot2)
ggplot(data, aes(x = 1:nrow(data), y = `T (degC)`)) + geom_line()

# first 10 days of temp data
ggplot(data[1:1440,], aes(x = 1:1440, y = `T (degC)`)) + geom_line()

# lookback = 1440 :: observations will go back 10 days
# steps = 6 :: observations will be sampled at one data point per hour
# delay = 144 :: targets will be 24 hours in the future

#' Preprocessing Data
#'
#' Scale inputs -> similar scale
#' Generator func -> takes current array of float data
#' yields batches of data from recent past

#' Example: Generator Function
#'
#' Sequence generator
sequence_generator <- function(start) {
  value <- start - 1
  function() {
    value <<- value + 1
    value
  }
}
gen <- sequence_generator(10)

#' Dataframe -> Matrix
data <- data.matrix(data[,-1])

#' Z-Score Scaling
train_data <- data[1:200000,]
mean <- apply(train_data, 2, mean)
sd <- apply(train_data, 2, sd)
data <- scale(data, center = mean, scale = sd)
View(data)

#' Generator
#'
#' generator() -> yields list(samples, targets)
#'
#' @param data :: original array of floating-point data
#' @param lookback :: how many timestamps back the input data should go
#' @param delay :: how many timesteps in the future target should be
#' @param min_index :: indices in data array that delimit which timesteps to draw from
#' @param max_index :: indices in data array that delimit which timesteps to draw from
#' @param shuffle :: whether to shuffle samples or draw in chrono order
#' @param batch_size :: number of samples per batch
#' @param step :: period, in timesteps, at which you sample data
#'
#' @return samples one batch input of data
#' @return corresponding array of target temperatures
generator <- function(data, lookback, delay, min_index, max_index,
                    shuffle = FALSE, batch_size = 128, step = 6) {
  # step = 6 :: one data point every hour
  if (is.null(max_index)) {
    max_index <- nrow(data) - delay - 1
  }

  i <- min_index + lookback

  function() {
    if (shuffle) {
      rows <- sample(c((min_index + lookback):max_index), size = batch_size)
    } else {
      if (i + batch_size >= max_index) {
        i <<- min_index + lookback
      }
      rows <- c(i:min(i + batch_size, max_index))
      i <<- i + length(rows)
    }
    samples <- array(0, dim = c(length(rows),
                                lookback / step,
                                dim(data)[[-1]]))
    targets <- array(0, dim = c(length(rows)))

    for (j in 1:length(rows)) {
      indices <- seq(rows[[j]] - lookback, rows[[j]],
                     length.out = dim(samples)[[2]])
      samples[j,,] <- data[indices,]
      targets[[j]] <- data[rows[[j]] + delay, 2]
    }
    list(samples, targets)
  }
}

#' Instatiate 3 Generators
#'
#' Training
#' Validation
#' Testing
lookback <- 1440
step <- 6
delay <- 144
batch_size <- 128

train_gen <- generator(
  data,
  lookback = lookback,
  delay = delay,
  min_index = 1,
  max_index = 200000,
  shuffle = TRUE,
  step = step,
  batch_size = batch_size
)

val_gen <- generator(
  data,
  lookback = lookback,
  delay = delay,
  min_index = 200001,
  max_index = 300000,
  step = step,
  batch_size = batch_size
)

test_gen <- generator(
  data,
  lookback = lookback,
  delay = delay,
  min_index = 300001,
  max_index = NULL,
  step = step,
  batch_size = batch_size
)

# how many steps to draw from val_gen in order to see
# entire validation set
val_steps <- (300000 - 200001 - lookback) / batch_size

test_steps <- (nrow(data) - 300001 - lookback) / batch_size

#' Baseline Model

evaluate_naive_method <- function() {
  batch_maes <- c()
  for (step in 1:val_steps) {
    c(samples, targets) %<-% val_gen()
    preds <- samples[,dim(samples)[[2]],2]
    mae <- mean(abs(preds - targets))
    batch_maes <- c(batch_maes, mae)
  }
  print(mean(batch_maes))
}

evaluate_naive_method()
# converting -> celsius
celsius_mae <- 0.28 * sd[[2]]

#' Simple Network
#'
#' fully connected model
#' flattens data -> runs through two dense layers
model <- keras_model_sequential() %>%
  layer_flatten(input_shape = c(lookback / step, dim(data)[-1])) %>%
  layer_dense(units = 32, activation = 'relu') %>%
  layer_dense(units = 1)

model %>% compile(
  optimizer = optimizer_rmsprop(),
  loss ="mae"
)

history <- model %>% fit_generator(
  train_gen,
  steps_per_epoch = 500,
  epochs = 20,
  validation_data = val_gen,
  validation_steps = val_steps
)

plot(history)

#' Recurrent Neural Network
model <- keras_model_sequential() %>%
  layer_gru(units = 32, input_shape = list(NULL, dim(data)[[-1]])) %>%
  layer_dense(units = 1)

model %>% compile(
  optimizer = optimizer_rmsprop(),
  loss = "mae"
)

history <- model %>% fit_generator(
  train_gen,
  steps_per_epoch = 500,
  epochs = 20,
  validation_data = val_gen,
  validation_steps = val_steps
)

#' Adding In Reccurent Dropout :: Combat Overfitting
model <- keras_model_sequential() %>%
  layer_gru(units = 32,
            dropout = 0.2,
            recurrent_dropout = 0.2,
            input_shape = list(NULL, dim(data)[[-1]])) %>%
  layer_dense(units = 1)

model %>% compile(
  optimizer = optimizer_rmsprop(),
  loss = "mae"
)

history <- model %>% fit_generator(
  train_gen,
  steps_per_epoch = 500,
  epochs = 40,
  validation_data = val_gen,
  validation_steps = val_steps
)

#' Stacking Recurrent Layers
model <- keras_model_sequential() %>%
  layer_gru(units = 32,
            dropout = 0.1,
            recurrent_dropout = 0.5,
            return_sequences = TRUE,
            input_shape = list(NULL, dim(data)[[-1]])) %>%
  layer_gru(units = 64,
            activation = 'relu',
            dropout = 0.1,
            recurrent_dropout = 0.5) %>%
  layer_dense(units = 1)

model %>% compile(
  optimizer = optimizer_rmsprop(),
  loss = "mae"
)

history <- model %>% fit_generator(
  train_gen,
  steps_per_epoch = 500,
  epochs = 40,
  validation_data = val_gen,
  validation_steps = val_steps
)