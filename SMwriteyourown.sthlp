{smcl}
{cmd:help SMwriteYourOwn}
{hline}

{title:Title}

{p2colset 3 23 23 2}{...}
{p2col :{bf:SMwriteYourOwn} {hline 2}}Facilities within {bf:{help StackMe}} for user-written 
commands: Using "hooks" built-in to {cmd:stackMe}'s {bf:{help genplace}} command to explore 
double-stacking and its alternatives when using multi-level (hierarchical) data{p_end}
{p2colreset}{...}


{synoptline}

{title:Introduction}

{p 2 2 2}
The Stata command language is designed for (and is well-suited to) incorporating user-written 
commands. The {help StackMe} suite of commands can readily be extended by anyone with moderate 
programing skills simply by following the Stata Manual instructions for program-writing in 
Stata. But for people without programming skills, the Stata command language makes it possible 
to provide "hooks" onto which users can "hang" snippets of code that call for hardly more 
programming skill than is needed to employ a package like {help StackMe}. In {cmd:StackMe} such 
hooks are built in to the {help genplace:{ul:genpl}ace} command.{p_end}

{p 2 2 2}
{help genplace} is the {help stackMe} command that allows users to "place" stacks (or the batteries 
underlying those stacks) in terms of mean values of the stacks/batteries concerned. A "{bf:call}" 
option permits users to define a different basis for placing stacks/batteries, should they wish 
(perhaps the median or the largest value). That same {opt cal:l} option permits any Stata program 
to be invoked, including programs written by the user. Such programs can be relatively trivial, 
hardly going beyond invoking a Stata command to perform a data transformation separately for each 
context when the desired Stata command does not itself permit the use of "by". An example of such 
a program is the model program provided with {cmd:StackMe} that calculates the degree of polarization 
exhibited by different party systems. That program can readily be copied and changes made to the 
equation it impliments so as to produce a program that calculates some other systemic measure. In 
this help file we walk the user through this program before moving on to a more elaborate model 
program at the cutting edge of research with election studies – a cutting edge that probably has 
analogies in other academic disciplines that employ multi-level (hierarchical) data.{p_end}

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
according to the political issues that shape electoral appeals made by those parties, by the particular 
media outlets (television stations, newspapers) that transmit those appeals, or in a number of other 
ways. Focusing on issues as our second criterion of interest, data might be stacked either according 
to the parties that focus on those issues or according to the issues that parties focus on. Or the 
data might be stacked by both parties and issues, producing so-called "doubly-stacked" data that has 
issues nested within parties within respondents (or parties within issues within respondents). See 
stackMe's {help stackme##Genericvariable:Affinity measures} help text.{p_end}

{p 2 2 2}
The {help stackme} package does not provide a command to doubly-stack a dataset – that would be done 
simply by running the command {help {ul:genst}acks} on already-stacked data. In the example shown 
below, the command:{break}

{p 4}{cmd:genstacks lrp1 lrp2}{opt , nocheck replace}{break}

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
  | 2    3.3  3.0  5.4 6.5 | ––––––> | 2  1  3.3  5.4 6.5 | ––––––> | 2 2 1  3.0 5.4 |
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
been generated by Stata when producing a doubly-reshaped dataset. {cmdab:genst:acks} instead saves 
two variables ({it:{cmd:SMunit}}, equivalent to the {it:{cmd:i}} index, and {it:{cmd:SMstkid}}, 
equivalent to the {bf:{it:j}} index). When doubly-stacking a dataset the {help genstacks} 
command will generate versions of these two generated variables called {it:{cmd:S2unit}} and 
{it:{cmd:S2stkid}} that identify the units and stacks in a doubly-stacked Dataset.{break} 
{space 3}{bf:Note} that while the Stata {help reshape}'s {bf:{it:j}} index does not identify reshaped 
observations(units) other than by their sequential position, {cmd:stackMe}'s {cmd:genstacks} 
provides a supplementary means of identifying specific stacks by means of another system 
variable, {bf:{it:SMitem}}, which can identify generated stacks by their original unstacked 
values, even if not sequential – in this regard Stata's {help reshape} command is limited 
in the same way as Stata's {help tab1} command, for which {help stackMe} also provides a more 
suffix-aware counterpart with its {help gendummies:{ul:gendu}mmies} command. Returning to the 
{bf:{it:SMitem}} variable, this can be especially helpful if it is associated with value labels 
that provide textual information about each stack.{p_end}

{p 2 2 2}
The fact that data can be doubly-stacked does not mean that this should always be the procedure 
adopted for research with cross-nested hierarchical data. Developing the above example of issues 
within parties (or parties within issues), double-stacking the data will, at minimum, double the 
size of the dataset (if there are two issues, as in the illustration). But two issues are nothing. 
Thirty would be more reasonable in a research project regarding issues. Ten would probably be the 
minimum for research using issues as control variables. But a ten-fold expansion of an already 
very large dataset brings with it the prospect of datasets with several millions of observations – 
big even by Stata's standards, and calling for analyses that could take hours rather than Stata's 
normally instantaneous response to estimation commands.{p_end}

{p 2 2 2}
There is little question that double-stacking would provide the gold standard for serious study of 
issue effects and, in this help-file, we lay the groundwork for generating affinity measures for 
doubly-stacked data – our final topic. But we build up to that topic by talking first about the 
analysis of subordinate batteries (defined above) that have not yet been doubly-stacked. Such procedures 
offer benefits in terms of data storage and execution time when conducting exploratory studies, or to 
use subordinate battery items as as control variables. This is the substantive topic explored in the 
next section of this illustrative helpfile, the next step on the way to contributing user-supplied 
programs that will run under {help StackMe}.{p_end}


{space 2}{title:Baby steps: simple strategies for summarizing subordinate battery values}

{p 2 2 2}
In what follows we will refer to the unstacked values shown in the "long" version of the earlier 
illustration as a "subordinate battery" of items – in this case subordinate to the {it:{bf:pty}} stub 
variable. Those subordinate values do not need to be stacked in order to be represented in a 
meaningful fashion for analysis in a "long" format analysis. For example, the command:{break}

{p 4 4}{cmd:genplace iss1-iss9,} {opt call( egen max_iss = rowmax(iss* ) )}{break}

{p 2 2 2}
would generate, separately for each context and stack, a pp_-prefixed variable (the default unless 
the {cmdab:genpl:ace} {opt ppr:efix} option is used to set a different prefix) recording the 
largest value in any of issues 1 to 9 across the whole row of issues in the subordinate battery 
(the asterisk in the call on Stata's {cmd:rowmax} function performs just as it would if that 
command had been typed into Stata's command window). Using the {opt rowmean} function would 
generate the average value of items in that battery. Either of these, or both of them together, or 
all of the {it:iss*} variables taken together in a multiple regression estimation command (such as 
would be produced by a {help genyhats:{ul:genyha}ts}}) multivariate analysis, would provide valuable 
insight into the power of issues to structure party preferences or choices without need for 
doubly-stacked data.{p_end}

{p 2 2 2}
What we are doing with the above functions is to characterize a list of variables in terms that make 
sense theoretically, without needing to know the actual identity of each variable – very much as we do 
when using stacked data for {help stackme##Genericvariable:generic variable} analysis). A 
rather different sort of concept often thought to characterize issues or parties is their polarization. 
But obtaining a polarization measure takes rather more than accessing a 
Stata function. We need a short Stata program to sum up the various components of the required 
equation, responding to the call illustrated in the following {cmdab:genpl:ace} command:{p_end}

{p 4 4}{cmd:genplace lrp1-lrp9 [pw=oweight],} {bf:{opt call(SMpolarizindex po_)}}{break}

{p 2 2 2}
The {opt call} option in this command leads {cmd:genplace} to issue the command named in that option 
and add the remaining option(s) supplied in the {opt call} option-string. In the case of {cmd:SMpolarizIndex} 
the only remaining option is the string of characters "po_" that the {cmd:SMpolarizIndex} command is 
be programmed to recognize as the prefix to be used for the variable names that will identify the new 
measures, one measure for each of the parties whose left-right locations were held by the variables in 
the {cmdab genpl:ace} variable list, a feature that is common to all stackMe commands. This call is 
made without need for {cmdab:genpl:ace} to know what will be done with information transferred to the 
optioned program. A few paragraphs below we will see the Stata code executed by {cmd:genplace} in 
response to the optioned {opt call}; but first we need a gentle introduction to Stata programming. 


{space 2}{title:Stata programming for beginners (this section can be skipped by those who do not need it)}
{p 2 2 2} 
/*Here we use a flow diagram to illustrate how subroutine calls fit in the general picture*/


Users unfamiliar with Stata programming should not hesitate to 
refer to standard Stata help-files for assistance, starting with the helpfile {help Programming Stata} 
and moving on to more specific help files such as help {help gettoken} that might demystify the first 
line of Stata code that follows:{p_end}


{col 5}{bf:gettoken cmd opts : call} {col 43} // Split {opt call} option-string into 1st word (cmd) & rest (opts)
{col 5}{bf:`cmd' `opts'}			 {col 43} // Issue `cmd' with specified options


{p 2 2 2}
But there is one piece of information that is needed immediately in order to understand the the two lines 
of code printed above. Stata programmers make ubiquitous use of what Stata calls a 'local macro' (or 'local' 
for short), each of which normally consists of a name that stands for (or points to) another name or list 
of names or other such string of text. The local name must be enclosed in single quotation marks each time 
it is used (as in line 2 of the two lines above), except when the local name is being used in a function 
designed specifically to manage local macros (as in line 1). These two lines first use the macro function 
{cmd gettoken} to unpack into two components the name of the program that was called ({cmd:SMpolarizIndex} 
and a prefix string "po_", in this case). Function {cmd:gettoken} splits the local named after the colon 
(a local that would be referred to as `call' if it was not being used in a macro function) into a first word 
("SMpolarizIndex"), put into a local that it names `cmd', and the rest of the `call' text string that it 
puts into a local that it names `opts'. The local names `cmd' and `opts' already appeared in the {opt:call} 
option that eds the {Cmdab:genpl:ace} command that was illustrated towards the end of the previous section 
of this helpfile. With our new appreciation for {cmd:Stata} local macros we can now pick up the story where 
it was left with that command.

{p 2 2 2}
Next comes some of the Stata code that is provided by the user in response to the SMpolarizindex call:{p_end}

{p2colset 5 26 25 1}
{space 4}{bf:program define SMpolarizIndex}	{col 42} // Name of program called by {cmdab:genpl:ace} (rest of command line is
{space 4}	   			{col 42} //  processed by the 'args' line that follows)
{space 4}{bf:args opts} {col 42} // Establishes the arguments used when invoking this `cmd'
{space 4}	   			{col 42} // Next line refers to (global) varlist (counterpart to local)
{space 4}{bf:gettoken vars wt:(global)varlist, p("[")} {col 45}// Split varlist from appended weight expression (the global
{space 4}	   			{col 45} //  varlist was supplied by {cmd:genplace}); the weight expression
{space 4}	   			{col 45} //  will be needed by some users; the ', p("[")' suffix 
{space 4}	   			{col 45} //  provides a parsing character that replaces the default
{space 4}	   			{col 45} //  space used earlier to define word boundaries)
{space 4}	   			{col 45} 
{space 4}{bf:local prfx = word("`opts'",1)} {col 45} // Get what we need from the generic `opts' string
{space 4}	   			{col 45} // (for this `cmd', only a prefix string was required)

{space 4}{bf:foreach var of varlist vars} {  {col 45} // Cycle thru each `lrp' in the {bf:genplace} varlist
{space 4}    :			{col 45} // (varlist holds left-right placements of each party)
{space 4}    :
{space 4}    :			{col 45} // Code implementing Dalton's Polarization Index
{space 4}    :
{space 4}    {bf:generate `prfx'`var' = ...} {col 45} // Assign each result to successive (now "po_"-prefxd) vars
{space 4}    : 			{col 45} // (separately for each combination of stack & context;
{space 4}{bf:}} {bf://next `var'}	{col 45} //  a service provided automatically by stackMe according
{space 4}	   			{col 45} //  to user-supplied options for the {cmdab:genpl:ace} command)

{space 4}{bf:end polarizIndex}	{col 45} // Additional details are in the {help SMpolarizindex} help file
{space 4}	   			{col 45} // The full program is in the {bf:polarizindex.ado} file, 
{space 4}	   			{col 45} //  distributed with the {bf:stackMe} package.


{p 2 2 2}
The 'SM' prefix to the user-provided command name is not required but is strongly recommended to ensure a 
unique name and reveal the program's provenance. The methods illustrated in the call to that user-defined 
program, and in the program itself, involve a generic command issued from within {cmdab:genpl:ace} without 
reference to what that command will do. Any user-written program could have been invoked, using any number 
of positional options and/or an options-list of any length and content, provided it was enclosed in double-quotes. 
The called program is usually called repeatedly, once for every combination of stack and context for every 
variable listed in the {cmd:genplace} command-line, so all the heavy lifting is done outside the user-defined 
program.{break}
{space 3}Just how much heavy lifting is done by the {cmdab:genpl:ace} command is for the user to decide.
Not only does the user decide whether contextual differences should be taken into account or whether 
the data should be weighted, and so forth; but the user also decides whether to take advantage of 
{cmdab:genpl:ace}'s primary purpose, which is to place the variables that it processes. By default it will do 
this, so long as the user-provided program assigns the placement indicators (those generated by the 
{bf:call}ed program) to the variables in which {cmdab:genpl:ace} expects to find them: the m_-prefixed 
versions of the variables to be placed.{p_end}


{space 2}{title:A next step: using the {opt call} option to generate affinity measures for doubly-stacked data}

{p 2 2 2}
In the previous section we focused on substitutes for doubly-stacked data using what we referred to as 
"subordinate batteries" of variables. In this section we consider how a researcher might deal with 
data in which the subordinate batteries had themselves been stacked (probably by invoking {help genstacks}
with data that was already in "long" format – see the illustration earlier in this help text). With such 
data there may be need for more elaborate generic variables (see the "generic variables" section of the 
{help stackMe} help text) than those produced by {help gendist} and {help genyhats}. Here we step through 
a user-supplied program that produces such a generic measure. The measure concerned is the measure of 
"issue yield" introduced in the {help genplace} help file.{break} 

{space 2}[More to come]
