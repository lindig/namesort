
# Namesort

Namesort is a small command line utility to sort a list of names by their
last name. This is a typical task when lists of names are maintained for
minutes and such where you might not want to use Lastname, Firstname but
sill need a way to sort names by last name.  The list of names is read from
a file or stdin, sorted, and emitted to stdout:

    $ cat test.txt 
    Dr. House
    Otto von Bismark
    Professor Donald E. Knuth
    Christian
    Gertrud von Le Fort
    Prof. Dr. Kurt Melhorn
    Charles-Michel de l'Epée
    Peter von der Osten-Sacken
    Duke Ellington
    Bernt Ture von zur Mühlen

    $ namesort test.txt 
    Otto von Bismark
    Charles-Michel de l'Epée
    Christian
    Duke Ellington
    Gertrud von Le Fort
    Dr. House
    Professor Donald E. Knuth
    Prof. Dr. Kurt Melhorn
    Bernt Ture von zur Mühlen
    Peter von der Osten-Sacken


Sorting names is done heuristically by trying to identify the last name
which might be preceded by academic titles, first names and prefixes. The
last name for each entry is then used for sorting. The rules for sorting
names vary greatly from country to country. For a discussion see:

    http://de.wikipedia.org/wiki/Hilfe:Personendaten/Name
    http://en.wikipedia.org/wiki/Wikipedia:Categorization_of_people

There is probably no way to automatically determine the correct order in
all cases automatically. Indeed, in the example above `Gertrud von Le
Fort`, `Bernt Ture von zur Mühlen` and `Charles-Michel de l'Epée` should
have not been ordered according the last word but the second last word of
the name. So the tool is not perfect.

# Implementation, Building, and Installation

Namesort is implemented in Objective Caml and has no external code
dependencies. It is written as a literate program (the code is in
namesort.lp) and you need Lipsum to build it. Lipsum is another tool
written in Objective Caml that can be downloaded from GitHub. The Makefile
contains instructions for doing so:

    make lipsum
    # edit Makefile to use locally installed lipsum
    make
    # edit Makefile for installation, especially PREFIX
    make install

For installation, check the Makefile and use `make install`. This target
builds a Unix manual page that is also installed. The manual page is
created with Perl's `pod2man` tool which typically is installed on a
developer machine.

The code is portable but the build and installation process assumes
a Unix environment.

# Encoding

Lipsum assumes so far input to be Latin-1 encoded. Switching to UTF-8 will 

# Algorithm

Namesorts works as follows: it reads input line by line and splits each
line into components. Each component is tagged. The most important
tag is Name which indicates that the component it should be considered for
determining the order of lines. For example:

    Otto von Bismark
    Professor Donald E. Knuth
    Dr. House
    Prof. Dr. Kurt Melhorn

These lines are split, tagged, and  ordered each by their tag as follows:

    N:Bismark N:Otto L:von S:  S: 
    N:House T:Dr. S: 
    N:Knuth N:E. N:Donald T:Professor S:  S:  S: 
    N:Melhorn N:Kurt T:Dr. T:Prof. S:  S:  S: 

A word tagged with `N` is considered a name component. The tool orders
lines by the _last_ name component in each line. A word tagged with `T` is
considered a title which should not be considered for line ordering.
Lower-case words tagged `L` are also considered not relevant.

The tool emits the input from above sorted in this way:

    Otto von Bismark
    Dr. House
    Professor Donald E. Knuth
    Prof. Dr. Kurt Melhorn

# Copyright

See file LICENSE.txt

# Author

Christian Lindig <lindig@gmail.com>
   

