Calling frog from R
========================================================

Frog is a lemmatizer and dependency parser for Dutch which can also be run as a server.
This package contains functions for connecting to a frog server from R and creating a document-term matrix from the resulting tokens. Since this yields a standard `tm` term-document matrix, it can be used e.g. for [corpus analysis](https://github.com/kasperwelbers/corpus-tools/blob/master/howto/howto_compare_corpora.md),  [topic modeling](https://github.com/kasperwelbers/corpus-tools/blob/master/howto/howto_latent_dirichlet_allocation_topmod.md), or machine learning using [RTextTools](http://www.rtexttools.net)

See http://ilk.uvt.nl/frog/ for more information on Frog.

Installing and running the frog server
----

The frog daemon (server) needs to be running before you can this package.
See http://ilk.uvt.nl/frog/ for documentation and installation instructions.

To install frog on debian/ubuntu you can use apt:

```{bash}
$ sudo apt-get install frog frogdata ucto
```

To run the frog server on port 9772, use:

```{bash}
$ frog -S 9772
```

If you only want to pos-tag and lemmatize, 
you can skip the parsing and morphological analysis to speed up the analysis and conserve memory:

```{bash}
$ frog --skip=acpm
```

Installing frogr
----

`frogr` can be installed directly from this github repository using devtools:


```r
if (!require(devtools)) {install.package("devtools"); library(devtools)}
install_github("frogr", username="vanatteveldt")
library(frogr)
```

If devtools is unavailable (e.g. on Windows), you can also copy the file [frog.r](R/frog.r) and source it directly. 
In that case, make sure the packages `tm`, `Matrix` and `zoo` are installed.

Calling frog
---

The function `call_frog` calls the frog server with a give text and results a data frame:


```r
text = c("Mijn kat Toby heeft nooit van andere katten gehouden.",
         "Maar andere katjes houden wel van hem!")
tokens = call_frog(text, host="localhost", port=9772)
```

```
## Frogging document 1: 53 characters
## Frogging document 2: 38 characters
```

```r
head(tokens)
```

```
##   docid sent position  word  lemma    morph
## 1     1    1        1  Mijn   mijn   [mijn]
## 2     1    1        2   kat    kat    [kat]
## 3     1    1        3  Toby   Toby   [Toby]
## 4     1    1        4 heeft hebben [heb][t]
## 5     1    1        5 nooit  nooit  [nooit]
## 6     1    1        6   van    van    [van]
##                                            pos   prob   ner  chunk parse1
## 1 VNW(bez,det,stan,vol,1,ev,prenom,zonder,agr) 0.9981     O   B-NP      2
## 2                  N(soort,ev,basis,zijd,stan) 0.9990     O   I-NP      4
## 3                              SPEC(deeleigen) 1.0000 B-PER   B-NP      2
## 4                             WW(pv,tgw,met-t) 0.9996     O   B-VP      0
## 5                                         BW() 0.9997     O B-ADVP      4
## 6                                     VZ(init) 0.9593     O   B-PP      9
##   parse2 majorpos
## 1    det      VNW
## 2     su        N
## 3    app     SPEC
## 4   ROOT       WW
## 5    mod       BW
## 6    mod       VZ
```

Note that if you run frog with the `--skip=` argument, some columns will only contain NA values.
The `sentence` and `majorpos` columns are not produced by frog but included here for convenience. `majorpos` is simply the part of the POS tag before the first parenthesis. 

Creating a document-term matrix
----

To create a document term matrix from the frog output (or in fact from any list of tokens), you can use the `create_dtm` function:


```r
m = create_dtm(tokens$docid, tokens$lemma)
as.matrix(m)
```

```
##     Terms
## Docs . ander hebben houden kat mijn nooit Toby van ! hem maar wel
##    1 1     1      1      1   2    1     1    1   1 0   0    0   0
##    2 0     1      0      1   1    0     0    0   1 1   1    1   1
```

Of course, you can also first select to e.g. only keep nouns and verbs:


```r
subset = tokens[tokens$majorpos %in% c("N", "WW"), ]
m = create_dtm(subset$sent, subset$lemma)
as.matrix(m)
```

```
##     Terms
## Docs hebben houden kat
##    1      1      2   3
```

As you can see, all forms of cat (_kat_, _katten_, _katjes_), love (_houdt_, _houden_), and have (_heeft_) are properly lemmatized.

