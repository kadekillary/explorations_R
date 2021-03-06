data(iris)
View(head(iris, 20))

iris_sub <- iris[1:100, c(1, 3, 5)]
names(iris_sub) <- c("sepal", "petal", "species")
View(iris_sub)

library(ggplot2)

ggplot(iris_sub, aes(x = sepal, y = petal)) +
  geom_point(aes(colour = species, shape = species), size = 3) +
  xlab("Sepal Length") +
  ylab("Petal Length") +
  ggtitle("Species vs Sepal and Petal Length")

euclidean.norm <- function(x) {sqrt(sum(x * x))}

distance.from.plane <- function(z, w, b) {
  sum(z * w) + b
}

classify.linear <- function(x, w, b) {
  distances <- apply(x, 1, distance.from.plane, w, b)
  return(ifelse(distances < 0, -1, + 1))
}

perceptron <- function(x, y, learning.rate = 1) {
  w = vector(length = ncol(x)) # initialize weights
  b = 0 # initialize bias
  k = 0 # count updates
  R = max(apply(x, 1, euclidean.norm))
  mark.complete = TRUE

  while (mark.complete) {
    mark.complete = FALSE
    yc = classify.linear(x, w, b)
    for (i in 1:nrow(x)) {
      if (y[i] != yc[i]) {
        w = w + learning.rate * y[i] * x[i,]
        b = b + learning.rate * y[i] * R^2
        k = k + 1
        mark.complete = TRUE
      }
    }
  }
  s <- euclidean.norm(w)
  return(list(w = w / s, b = b / s, updates = k))
}

x <- cbind(iris_sub$sepal, iris_sub$petal)
y <- ifelse(iris_sub$species == "setosa", +1, -1)
p <- perceptron(x, y)

plot(x, cex = 0.2)
points(subset(x, y == 1), col = "black", pch = "+", cex = 2)
points(subset(x, y == -1), col = "red", pch = "-", cex = 2)
intercept <- - p$b / p$w[[2]]
slope <- - p$w[[1]] / p$w[[2]]
abline(intercept, slope, col = "green")
