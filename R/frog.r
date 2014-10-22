library(zoo)
library(Matrix)
library(tm)

#' Call a frog (Dutch lemmatizer and dependency parser) instance running in daemon mode
#' 
#' See http://ilk.uvt.nl/frog/
#' To install frog and run as daemon (assuming debian/ubuntu), run:
#' $ sudo apt-get install frog frogdata ucto
#' $ frog -S 9772
#' 
#' A separate call to frog is made for each text in the text input vector.
#' 
#' Note that if something is wrong, it is quite possible that this function will totall hang
#' your R session as it is waiting for output on the socket, so use with caution!
#' 
#' @param text: The text(s) to parse
#' @param host: The hostname for the frog server
#' @param port: The port the frog server is listening on
#' @param verbose: If true, output a message for each document
#' @return a data frame of tokens with columns for lemma, pos, etc 
#' @export
call_frog <- function(text, host="localhost", port=9772, verbose=T) {
  # establish connection and add finalizing code
  socket <- make.socket(host, port)
  on.exit(close.socket(socket))
  # call frog, ending with EOT
  result <- NULL
  for (i in 1:length(text)) {
    t = text[i]
    if (verbose) message("Frogging document ",i,": ", nchar(t), " characters")
    tokens = do_call_frog(socket, t)
    tokens$docid = i
    result = rbind(result, tokens)
  }
  result[, c(ncol(result), ncol(result)-1, 1:(ncol(result)-2))]
}

#' Do the actual call to frog, returning the data frame
do_call_frog <- function(socket, text) {
  write.socket(socket, text)
  write.socket(socket, "\nEOT\n")
  # read until 'READY' is found
  output <- ""
  while (!grepl("\nREADY\n$", output)) {
    output = paste(output, read.socket(socket), sep="")  
  }
  output = gsub("READY\n$", "", output)
  # read output and label columns
  con <- textConnection(output)
  result = read.table(con, header=F, sep="\t")
  colnames(result) <- c("position", "word", "lemma", "morph", "pos", "prob",
                        "ner", "chunk", "parse1", "parse2")
  result$majorpos = gsub("\\(.*", "", result$pos)
  # assign sentence number by assigning number when position == 1 and filling down into NA cells using zoo::na.locf
  firstword = rownames(result)[result$position == 1]
  result$sent[rownames(result) %in% firstword] = 1:length(firstword)
  result$sent = na.locf(result$sent)
  result
}

#' Create a document term matrix from a token list
#' 
#' @param docs: a vector that identifies to which document a token belongs
#' @param terms: a vector of terms of length equal to docs
#' @param freqs: an optional vector giving the frequency of each term
#' @param weighting: the optional weighting for tm (default: term frequency)
#' @return an object of type DocumentTermMatrix (from the tm package)
#' @export
create_dtm <- function(docs, terms, freqs=rep(1, length(terms)), weighting=weightTf) {
  d = data.frame(doc=docs, term=terms, freq=freqs)
  d = aggregate(freq ~ doc + term, d, FUN='sum')
  docnames = unique(d$doc)
  termnames = unique(d$term)
  sm = spMatrix(nrow=length(docnames), ncol=length(termnames),
                match(d$doc, docnames), match(d$term, termnames), d$freq)
  rownames(sm) = docnames
  colnames(sm) = termnames
  as.DocumentTermMatrix(sm, weighting=weighting)
}

result = call_frog("Een zin is een test. Maar nog een zin?\nEven Apeldoorn bellen!")
docs = result$sent
terms = result$lemma
freqs=rep(1, length(terms))

m = create_dtm(result$sent, result$lemma)
as.matrix(m)

nouns = result[result$majorpos == "N", ]
m = create_dtm(nouns$sent, nouns$lemma)
as.matrix(m)
