{smcl}
{cmd:help genWriteYourOwn}
{hline}

{title:Title}

{p2colset 3 23 23 2}{...}
{p2col :{bf:genWriteYourOwn} {hline 2}}Facilities within {bf:{help StackMe}} for user-written 
commands: Using "hooks" built-in to {cmd:stackMe}'s {bf:{help genplace}} command to explore 
double-stacking and its alternatives when using multi-level (hierarchical) data{p_end}
{p2colreset}{...}


{synoptline}

{title:Introduction}

{p 2 2 2}
The Stata command language is designed for (and is well-suited to) incorporating user-written 
commands. The {help StackMe} suite of commands can readily be extended by anyone with programing 
skills simply by following the Stata Manual instructions for program-writing in Stata. But 
for people without programming skills, the Stata command language makes it possible to 
provide "hooks" onto which users can "hang" snippets of code that call for hardly more 
programming skill than is needed to employ a package like {help StackMe}. In {cmd:StackMe} 
such hooks are built in to the {help genplace} command.{p_end}

{p 2 2 2}
{help genplace} is the {help stackMe} command that allows users to "place" stacks (or the batteries 
underlying those stacks) in terms of mean values of the stacks/batteries concerned. A "call" option 
permits users to define a different basis for placing stacks/batteries, should they wish (perhaps 
the median or the largest value). That same {opt cal:l} option permits any Stata program to be invoked, 
including programs written by the user. Such programs can be relatively trivial, hardly going beyond 
invoking a Stata command to perform a data transformation separately for each context when the desired 
Stata command does not itself permit the use of "by". An example of such a program is the 
model program provided with {cmd:StackMe} that calculates the degree of polarization exhibited by 
different party systems. That program can readily be copied and changes made to the equation it 
impliments so as to produce a program that calculates some other systemic measure. In this help file 
we walk the user through this program before moving on to a more elaborate model program at the 
cutting edge of research with election studies – a cutting edge that probably has analogies in other 
academic disciplines that employ multi-level (hierarchical) data.{p_end}

{p 2 2 2} 
The {help StackMe} package currently focuses on procedures that are well-established in political 
science and political sociology: procedures involving a single level of stacking (what Stata calls 
{help reshape}ing). There are many directions in which researchers are taking the subfield that 
require conceptualizing data in unfamiliar ways but, in line with the general objectives underlying 
the {cmd:stackMe} package, the particular cutting edge addressed in this help file involves data 
that might be considered suitable for double-stacking (explained below). We believe that the 
programming implications of such an enterprise will be pretty-much universal in their applicability 
across academic fields of study.{p_end}

{p 2 2 2}
Doubly-stacked data might be wanted when a researcher is working with more than a single criterion 
according to which variables could be grouped into batteries. In the {cmd:stackMe} help files, mention 
is often made of batteries of questions that have been grouped according to the different political 
parties about which survey questions had been asked. In voting studies, questions might also be grouped 
according to the political issues that shape electoral appeals to voters, made by those parties, by the 
particular media outlets (television stations, newspapers) that transmit those appeals, or in a 
number of other ways. Focusing on issues as our second criterion of interest, data might be stacked 
either according to the parties that focus on those issues or according to the issues that parties 
focus on. Or the data might be stacked by both parties and issues, producing so-called "doubly-stacked" 
data that has issues nested within parties within respondents (or parties within issues within 
respondents). See stackMe's {help stackme##Affinitymeasures:Affinity measures} help text.{p_end}

{p 2 2 2}
The {help stackme} package does not provide a command to doubly-stack a dataset – that would be done 
simply by running the command {help genstacks} on already-stacked data. In the example shown below, 
the command:{break}

{p 4}{cmd:genstacks lrp1 lrp2}{opt , context(cntry year)} {opt stackid(stkid)}{break}

{p 2 2 2}
would cause an imaginary dataset containing variables called "lrp1" and "lrp2" (for "left-right 
position of party 1" and "left-right position of party2") to be {help reshape}d from what Stata 
calls "wide" to "long" format, "stacking" their values on top of each other instead of leaving 
them next to each other. The two "iss" (for issue) variables are not mentioned in this {help genstacks} 
command but they are duplicated onto each row of the long-format dataset just as are all other 
variables not mentioned in the {cmd:genstacks} command, becoming what we will refer to as 
{bf:"subordinate batteries"} (a step on the way to becoming "doubly-stacked batteries"). A second 
{cmd:genstacks} command would complete the creation of a doubly-stacked dataset by operating on 
just the two "iss" (for issue) questions, producing the transposition of the long-format dataset 
into what we here label as "deep" format, with all other variables being duplicated as before.{p_end}

{asis}
                                                                           deep
                                              long                  +----------------+
              wide                   +--------------------+         | i j k  lrp iss |
  +------------------------+         | i  j  lrp iss1 iss2|         |----------------+
  | i   lrp1 lrp2 iss1 iss2|         |--------------------|         | 1 1 1  4.1 5.4 |
  |------------------------|   1st   | 1  1  4.1  5.4 6.5 |   2nd   | 1 2 1  4.5 5.4 |
  | 1    4.1  4.5  5.4 6.5 | reshape | 1  2  4.5  5.4 6.5 | reshape | 2 1 1  3.3 5.4 |
  | 2    3.3  3.0  5.4 6.5 | ------> | 2  1  3.3  5.4 6.5 | ------> | 2 2 1  3.0 5.4 |
  +------------------------+         | 2  2  3.0  5.4 6.5 |         | 1 1 2  4.1 6.5 |
                                     +--------------------+         | 1 2 2  4.5 6.5 |
                                                                    | 2 1 2  3.3 6.5 |
                                                                    | 2 2 2  3.0 6.5 |
                                                                    +----------------+
{smcl}

{p 2 2 2}
The "i" and "j" indices, shown in the illustration, are not used by {cmd:genstacks} but relate 
to the equivalent Stata {help reshape} command, whose help text provided the prototype for the 
above illustration. The {bf:{it:k}} index is invented by us as an imaginary index that might have 
been generated by Stata when producing a doubly-reshaped dataset. {cmd:genstacks} instead saves 
two variables ({it:_stackme_unit}, equivalent to the {bf:{it:i}} index, and {it:_stackme_item}, 
equivalent to the {bf:{it:j}} index). When doubly-stacking a dataset the {help genstacks} 
{opt ipr:efix} option would be needed to provide a different prefix that would serve as the {cmd:stackMe} 
equivalent to the illustrated {bf:{it:k}} index).{break} 
{space 3}{bf:Note} that the Stata {help reshape}'s {bf:{it:j}} index does not identify reshaped units
other than by their sequential position, whereas {cmd:genstacks}' {bf:{it:_stackme_item}} identifies 
generated stacks by their original unstacked identifiers, even if not sequential – in this regard 
Stata's {help reshape} command is limited in the same way as Stata's {help tab1} command, for 
which {help stackMe} also provides a more suffix-aware counterpart with its {help gendummies} command.
{p_end}

{p 2 2 2}
But the fact that data can be doubly-stacked does not mean that this should always be the procedure 
adopted for research with cross-nested hierarchical data. Developing the above example of issues 
within parties (or parties within issues), double-stacking the data will, at minimum, double the 
size of the dataset (if there are two issues, as in the illustration). But two issues are nothing. 
Thirty would be more reasonable in a research project regarding issues. Ten would probably be the 
minimum for research using issues as control variables. But a ten-fold expansion of an already 
very large dataset brings with it the prospect of datasets with several millions of cases – big 
even by Stata's standards, and calling for analyses that could take hours rather than Stata's 
normally instantaneous response to estimation commands.{p_end}

{p 2 2 2}
There is little question that double-stacking would provide the gold standard for serious study of 
issue effects and, in this help-file, we lay the groundwork for generating affinity measures for 
doubly-stacked data – our final topic. But we build up to that topic by talking first about the 
analysis of subordinate batteries (defined above) that have not yet been doubly-stacked. Such procedures 
offer benefits in terms of data storage and execution time when conducting exploratory studies, or to 
use subordinate battery items as as control variables. This is the substantive topic explored in the 
next section of this illustrative helpfile for those wanting to contribute user-supplied programs 
that will run under {help StackMe}.{p_end}


{title:Baby steps: simple strategies for summarizing subordinate battery values}

{p 2 2 2}
In what follows we will refer to the unstacked values shown in the "long" version of the earlier 
illustration as a "subordinate battery" of items – in this case subordinate to the {it:{bf:pty}} stub 
variable. Those subordinate values do not need to be stacked in order to be represented in a 
meaningful fashion for analysis in a "long" format analysis. For example, the command:{break}

{p 4 4}{cmd:genplace iss1-iss9,} {opt context(cntry year)} {opt stackid(stkid)} {bf:{opt call( egen max_* = rowmax(*) )}}{break}

{p 2 2 2}
would generate, separately for each context and stack, a variable that recorded the largest value 
in any of issues 1 to 9 across the whole row of issues in the subordinate battery. Using the 
{opt rowmean} function would generate the average value of items in that battery. Either of these 
(or both together in a multiple regression estimation command) would provide valuable insight 
into the power of issues to structure party preferences and choice without need for doubly-stacked 
data.{p_end}

{p 2 2 2}
What we are doing with the above functions is characterizing a list of variables in terms that make 
sense theoretically, without needing to know the actual identity of the variables – very much as we do 
when using stacked data for "generic variable analysis" (see the help text for {help stackMe}). A 
rather different sort of concept often thought to characterize issues or parties is their polarization. 
But characterizing parties or issues in terms of their polarization takes rather more than accessing a 
Stata function. We need a short Stata program to sum up the various components of the required 
equation, responding to the call optioned in the following {cmd:genplace} command:{p_end}

{p 4 4}{cmd:genplace lrp1-lrp9,} {opt context(cntry year)} {opt stackid(stkid)} {bf:{opt call(polarindex p_)}}{break}

{p 2 2 2}
The {opt call} option in this command leads {cmd:genplace} to issue the command named in that 
option, adding the remaining argument(s) supplied in the {opt call} string and a varlist 
naming the currently active variables (listed in the {cmd:genplace} command-line shown just above). 
This call is made without need for {cmd:genplace} to know anything about what will be done with 
information transferred to the optioned program. Just below is the code executed by {cmd:genplace} in 
response to the optioned {opt call}. Users unfamiliar with Stata programming should not hesitate to 
call on Stata help-files for assistance. For example, the {bf:Description} you will see when you type 
"help {help gettoken}" will demystify the first line of Stata code that follows:{p_end}
{smcl}


{col 5}{bf:gettoken cmd opts : call}{col 37}// Split the call option-string into command & options
{col 5}{bf:local vars ="`vars' [`weight']"}{col 37}// Extend current varlist with any weight expression
{col 5}{bf:`cmd' `vars',} {bf:opts("`opts'")}{col 37}// Issue `cmd' with extended varlist & specified opts


{p 2 2 2}
And here is some of the Stata code invoked by `cmd':{p_end}

{p2colset 6 26 25 2}
{space 4}{bf:program define polarindex}	{space 5} // Name of program invoked by {bf:genplace} (which added
{space 4}	   			{space 4}//  the current varlist and weight exp to the call)
{space 4}{bf:syntax anything, opts(string)} {space 2}// Describe the syntax used when invoking this `cmd'
{space 4}	   			{space 4}// ("vars[weight], opts" – opts hold just the pprefix)
{space 4}{bf:gettoken vars wt:anything,parse("[")} // Split `anything' into vars and wt (unused here)
{space 4}	   			{space 4}// (weight expression will be needed by some programs,
{space 4}	   			{space 4}//  so every user program needs these 3 lines of code)

{space 4}{bf:local prfx = word("`opts'",1)}   // Get what we need from the generic `opts' string
{space 4}	   			{space 4}// (for this `cmd', only a prefix string was required)

{space 4}{bf:foreach lrp of varlist vars} {   // Cycle thru each `lrp' in the {bf:genplace} varlist
{space 4}    ,				 // (varlist holds left-right placements of each party)
{space 4}    :
{space 4}    :				 // Code implementing Dalton's Polarization Index
{space 4}    '
{space 4}    {bf:generate `prfx'`lrp' = ...}  // Assign each result to the same (now "p_"-prefxd) var
{space 4}	   			{space 4}// (separately for each combination of stack & context)
{space 4}} //next `lrp'

{space 4}{bf:end polarindex}		{space 5} // See the file {bf:polarindex.ado} for the full program


{p 2 2 2}
The methods illustrated in the call to that user-defined program, and in the program itself, 
involve a generic command issued from within {cmd:genplace} without reference to what that command 
will do. Any user-written program could have been invoked using an option-list of any length that 
could contain any number (known to the called program) of one-word options, optionally followed by 
any number of same-length lists (provided the length concerned was held in a previous option). The 
one-word options are by default positional (as in our example); but they can also be named (eg
"pprefix:p_") using a colon to separate the option-name from the argument it transmits (the model 
program illustrated above did not need to check for colons because the positional nature of the 
argument was documented in the {cmd:genplace} help text). So the 
applicability of the {opt call} option, though not universal, is very broad. The called program 
is called repeatedly, once for every combination of stack and context for every variable list in 
the {cmd:genplace} command-line, so all the heavy lifting is done outside the user-defined program.
{p_end}


{title:A next step: using the {opt call} option to generate affinity measures for doubly-stacked data}

{p 2 2 2}
In the previous section we focused on substitutes for doubly-stacked data using what we referred to as 
"subordinate batteries" of variables. In this section we consider how a researcher might deal with 
data in which the subordinate batteries had themselves been stacked (probably by invoking {help genstacks}
with data that was already in "long" format – see the illustration earlier in this help text). With such 
data there may be need for more elaborate generic variables (see the "generic variables" section of the 
{help stackMe} help text) than those produced by {help gendist} and {help genyhats}. Here we step through 
a user-supplied program that produces such a generic measure. The measure concerned is the measure of 
"issue yield" introduced in the {help genplace} help file.{break} 

[More to come]
