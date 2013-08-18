
# Namesort

Namesort is a small command line utility to sort a list of names by their
last name. The list is read from a file or stdin, sorted, and emitted to
stdout.

Sorting names is done heuristically by trying to identify the last name
which might be preceded by academic titles, first names and prefixes. The
last name for each entry is then used for sorting. The rules for sorting
names vary greatly from country to country. For a discussion see:

    http://de.wikipedia.org/wiki/Hilfe:Personendaten/Name
    http://en.wikipedia.org/wiki/Wikipedia:Categorization_of_people

There is probably no way to automatically determine the correct order in
all cases automatically.

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

# Splitting a line into words

We use a lexer to split a name into components. The lexer is called once
per line (or name) for splitting. 

<<namesort.mll>>=
{
<<prologue>>
}
<<rules>>
{
<<epilogue>>
}
@

## Prologue

We define some helpful types and functions that we might call during lexing
actions.

<<prologue>>=
module L = Lexing   (* just an alias *)

exception Error of string
let error fmt = Printf.kprintf (fun msg -> raise (Error msg)) fmt

let get        = Lexing.lexeme
let (@@) f x   = f x (* helps to avoid parentheses: f @@ 3+4 = f (3+4) *)
let (@.) f g   = fun x -> f (g x) (* function composition *)
@

We try to tag each component of a name, including white space. 

<<prologue>>=
type tag        = Name | Title | TeX | LowerCase | Other | Space 
type component  = tag * string
type line       = component list
type file       = line list
@

<<prologue>>=
let tag = function
    | Name          -> 'N'
    | Title         -> 'T'
    | TeX           -> 'X'
    | LowerCase     -> 'L'
    | Other         -> 'O'
    | Space         -> 'S'

@ `tagged` takes a pair of a tag and a string and turns it into one string
that can be used for debugging.

<<prologue>>=
let tagged (t, str) = Printf.sprintf "%c:%s" (tag t) str

@ The `order` function defines the importance of tags for ordering words
within a name.

<<prologue>>=
let order = function
    | Name      -> 0
    | LowerCase -> 1
    | Other     -> 2
    | Title     -> 3
    | Space     -> 4
    | TeX       -> 5


@ Compare two components for sorting them by comparing their tags. Sorting
requires a stable sorting algorithm to preserve the given order of the same
tags. 

A line, which is a list of components, as it is returned by the scanner
(`read_line`) is in reverse order: the last word of the name comes first.
Since sorting put name components first, the last name component becomes
the first after `sort` was applied.

<<prologue>>=
let compare (x_tag,x_str) (y_tag,y_str) = 
    let x_ord = order x_tag in
    let y_ord = order y_tag in
        if      x_ord < y_ord then -1
        else if x_ord > y_ord then 1
        else    0

let sort (line:line) = List.stable_sort compare line

@ `finally f x cleanup` function provides resource cleanup in the presence
of exceptions: `f x` is computed as a result and `cleanup x` is guaranteed
to run afterwards. (In many cases `cleanup` will not use its argument `x`
but it can be convenient to have access to it.)

<<prologue>>=
type 'a result = Success of 'a | Failed of exn
let finally f x cleanup = 
    let result =
        try Success (f x) with exn -> Failed exn
    in
        cleanup x; 
        match result with
        | Success y  -> y 
        | Failed exn -> raise exn
@

## Rules

<<rules>>=
let space       = [  ' ' '\t' '~' '\r']
let nl          = ['\n']
let letter      = [^ ' ' '\t' '~' '\r' '\n'] 
let upper       = ['A' - 'Z' 'Ö' 'Ä' 'Ü'] (* not complete *) 
let lower       = ['a' - 'z' 'ö' 'ä' 'ü' 'ß'] (* not complete *)
let title       = "Dr" 
                | "Prof" "essor"?
                | "PhD"
                | "Do" ['c' 'k'] "tor"
@

In the rules below the rule that matches the longest string wins. When two
rules match a string, the first rule wins. For this reason it is important
that the title rule comes before the name rules.

The basic idea of `read_line` is to tag each word in a line as a component
and return a list of such pairs.

<<prologue>>=
let add f buffer words tag  = f ((tag, Lexing.lexeme buffer)::words) buffer
<<rules>>=
rule read_line words = parse 
    | eof            { if words = [] then None else Some words } 
    | nl+            { Some words } (* in reverse order *)
    | space+         { add read_line lexbuf words Space }
    | title "."?     { add read_line lexbuf words Title }
    | upper letter*  { add read_line lexbuf words Name  }
    | lower letter*  { add read_line lexbuf words LowerCase }
    | _              { add read_line lexbuf words Other }
@

<<epilogue>>=
let read_line: L.lexbuf -> line option = 
    function lexbuf -> read_line [] lexbuf

let read_file io =
    let lexbuf = Lexing.from_channel io in
    let rec loop lines =
        match read_line lexbuf with
        | None       -> lines
        | Some line  -> loop (line :: lines)
    in 
        loop []

@ `join` joins the strings that resulted from a line being split by the
scanner `read_line`.

<<epilogue>>=
let join ?sep:(sep="") (line:line) = String.concat sep @@ List.map snd line

type tagged_line =
    { keys:     string list (* lines are sorted by this *)
    ; tagged:   string      (* for debugging *)
    ; line:     string      (* line as it was read *)
    }

@ `prioritize` finds the words in each line that should be used for line
ordering and puts them into `keys`. It also re-creates the original line,
as stored in `line`. The string in `tagged` is only used for debugging. It
shows how words are tagged.

<<epilogue>>=
let prioritize (tagged_components:line) = 
    let sorted = sort tagged_components in
        { keys      = List.map snd sorted
        ; tagged    = String.concat " " @@ List.map tagged sorted
        ; line      = join @@ List.rev tagged_components 
        }

@ The sorting of all the lines from the input happens here.

<<epilogue>>=
let sort_by_keys tagged_lines =
    let cmp x y = Pervasives.compare x.keys y.keys in
        List.sort cmp tagged_lines

let sortnames ?debug:(debug=false) io =
    let lines  = read_file io in
    let lines  = List.map prioritize lines in
    let sorted = sort_by_keys lines in
        if debug then
            List.iter print_endline @@ List.map (fun x -> x.tagged) sorted
        else
            List.iter print_endline @@ List.map (fun x -> x.line) sorted

@ A small help message in case it is explicitly requested or when
we don't recognize the command line.

<<epilogue>>=
let usage this =
    List.iter prerr_endline
    [ this ^ " reads input line by line and expects each line to contain"
    ; "a name. It sorts lines by last names and emits them to stdout."
    ; ""
    ; this ^ " usage:"
    ; ""
    ; this ^ " file.txt         sort lines from file.txt"
    ; this ^ "                  sort lines from stdin"
    ; this ^ " -h               emit help to stderr"
    ; ""
    ; this ^ " -d file.txt      debuging output - show tags and sort keys"
    ; ""
    ; "(c) 2013 Christian Lindig <lindig@gmail.com>"
    ]

let main () =
    let argv        = Array.to_list Sys.argv in
    let this        = Filename.basename @@ List.hd argv in
    let args        = List.tl argv in    
        match args with
        | []            -> sortnames stdin
        | "-h"::_       -> usage this
        | [path]        -> finally sortnames (open_in path) close_in
        | "-d"::[path]  -> finally 
                                (sortnames ~debug:true) 
                                (open_in path) 
                                close_in
        | _             -> usage this

let () = 
    try
        if not !Sys.interactive then begin
            main (); exit 0
        end    
    with
        Sys_error(msg) -> Printf.eprintf "Error. %s\n" msg; exit 1  
@

# Tests

<<test.txt>>=
Otto von Bismark
Professor Donald E. Knuth
Dr. House
Christian
Gertrud von Le Fort
Prof. Dr. Kurt Melhorn
Duke Ellington
Charles-Michel de l'Epée
Peter von der Osten-Sacken
Bernt Ture von zur Mühlen
@

# Manual Page

The Unix manual page is written in Perl's POD format which I consider the
easiest way to write man pages while only relying on a tool that most
developers have installed.

<<namesort.pod>>=
=head1 NAME

namesort -- sort names by last name

=head1 SYNOPSIS

B<namesort> [I<file>]

B<namesort> B<-d> I<file>

B<namesort> B<-h>

=head1 DESCRIPTION

B<Namesort> reads input line by line from a named I<file> or from stdin if
no I<file> is given. Each line is expected to contain a person's name. The
lines are sorted by last name and emitted to stdout. 

Sorting names is done heuristically as conventions vary greatly among
countries. B<Namesort> tries to identify the last capitalized word in a
line and disregards academic titles.

=head1 OPTIONS

=over 4

=item B<-h>

Emit usage information to stderr and exit with exit code 1.

=item B<-d> I<file>

Emit debugging information. Input is read from I<file>.

=back

=head1 EXIT CODE

Upon successful completion the exit code is 0, and non-zero otherwise.
Error messages go to stderr.

=head1 AUTHOR

Christian Lindig <lindig@gmail.com>

=head1 COPYRIGHT

This tool and all its source code is in the public domain.
@

