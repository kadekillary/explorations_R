library(keras)

#' Load Data
imdb  <- dataset_imdb(num_words = 10000)

train_data  <- imdb$train$x
train_labels  <- imdb$train$y
test_data  <- imdb$test$x
test_labels  <- imdb$test$y

max(sapply(train_data, max))

#' Decoding -> Num :: Word
# decode back to english
word_index  <- dataset_imdb_word_index()
reverse_word_index  <- names(word_index)
names(reverse_word_index)  <- word_index

# deocdes review :: inidces are offset by 3 because 0, 1 and 
# 2 are reserved inidices for `padding,` `start of sequence` and `unknown`
decoded_review  <- sapply(train_data[[1]], function(index) {
  word  <- if (index >= 3) reverse_word_index[[as.character(index - 3)]]
  if (!is.null(word)) word else "?"
})
cat(decoded_review)

#' Turn Lists -> Tensors
# one-hot encode list -> vector of 0 and 1s
vectorize_sequences  <- function(sequences, dimension = 10000) {
  # dimension is 10000 to account for number of encodings
  # sequence [3,5] would be blank for all 10,000 except 3 and 5 indices
  # creates all-zero matrix of shape (length(sequences), dimension)
  results  <- matrix(0, nrow = length(sequences), ncol = dimension)
  for (i in 1:length(sequences)) {
    # sets specific indices of results[i] to 1s
    results[i, sequences[[i]]]  <- 1
  }
  results
}

x_train  <- vectorize_sequences(train_data)
x_test  <- vectorize_sequences(test_data)
# convert :: int -> numeric
y_train  <- as.numeric(train_labels)
y_test  <- as.numeric(test_labels)

#' Building Network

# Q :: How many layers to use?
# Q :: How many hidden units to choose for each layer?

model  <- keras_model_sequential() %>%
  layer_dense(units = 16, activation = 'relu', input_shape = c(10000)) %>%
  layer_dense(units = 16, activation = 'relu') %>%
  layer_dense(units = 1, activation = 'sigmoid')

model %>% compile(
  optimizer = "rmsprop",
  loss = "binary_crossentropy",
  metrics = c('accuracy')
)

#' Validation
val_indices  <- 1:10000

x_val  <- x_train[val_indices,]
partial_x_train  <- x_train[-val_indices,]

y_val  <- y_train[val_indices]
partial_y_train  <- y_train[-val_indices]

history  <- model %>% fit(
  partial_x_train,
  partial_y_train,
  epochs = 20,
  batch_size = 512,
  validation_data = list(x_val, y_val)
)

plot(history)

#' Stop Training After 4 epochs :: Avoid Overfitting
model  <- keras_model_sequential() %>%
  layer_dense(units = 16, activation = 'relu', input_shape = c(10000)) %>%
  layer_dense(units = 16, activation = 'relu') %>%
  layer_dense(units = 1, activation = 'sigmoid')

model %>% compile(
  optimizer = 'rmsprop',
  loss = 'binary_crossentropy',
  metrci = c('accuracy')
)

model %>% fit(x_train, y_train, epochs = 4, batch_size = 52)
results  <- model %>% evaluate(x_testm, y_test)
