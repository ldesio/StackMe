{smcl}
{cmd:help {cmdab:genst:acks}}
{hline}

{title:Title}

{p2colset 5 18 18 2}{...}
{p2col :{cmdab:genst:acks} {hline 2}}Stacks a dataset for analysis in {help reshape}d (long) format (be sure 
you are familiar with concepts introduced in StackMe's {help stackme##Datastacking:Data stacking} 
help-text before proceeding){p_end}
{p2colreset}{...}


{title:Syntax}

{p 6 28 2}
{opt genst:acks} (unstacked) {varlist} [  {space 2}|| {break}
{varlist} ]  [      ||  ... ]   || {break}
{varlist} , options{p_end}
{space 4}	or

{p 6 32 2}
{opt genst:acks} (stacked) {it:{help varlist:namelist}}{cmd:,} {it:options} 


{p 2 2 2}where {varlist} in syntax 1 lists the names of variables constituting one or more 
so-called {it:batter(ies)} of items, each {help stackMe##Datastacking:battery} delimited by "||", 
whereas {help varlist:namelist} in syntax 2 lists the textual "stubs" that will name the same variables 
after reshaping – one stub in Syntax 2 for each varlist in Syntax 1. So syntax 2 involves less 
typing and provides less opportunity for error.

{p 2 2 2}
Stubnames must be the same for all variables in a battery. If a battery's 
variables do not have consistent stubnames with numeric suffixes then they need 
to be {help rename}d before invoking {cmd:genstacks}. See {help rename group}, especially rule 17.

{p 2 2 2}
{cmdab:genst:acks} does not support {ifin} or {weight} expressions. Reshaping applies to an entire dataset 
as it stands when reshaped. The batteries listed in successive varlists (or equivalent stubnames) 
{bf:must all relate to batteries that concern the same items} (schools, political parties, issues, etc.) 
so that each battery derives from a series of essentially identical questions that were asked in the same 
sequence regarding each school, party, etc.  Because the command is focused on a specific set of items, 
it may be necessary to stack the same dataset more than once (either {help stackme##Doublydtackeddata:double-stacking} 
the dataset or saving stacked data for each set of items in a different .dta file, each named for the items 
that are its focus).

   
{synoptset 22 tabbed}{...}
{synopthdr}
{synoptline}
{p2colset 5 26 24 2}
{synopt :{opt con:textvars(varlist)}}{bf:THERE IS NO SUCH OPTION} for command {cmdab:genst:acks}. The variables 
identifying different contexts within which batteries will be separately reshaped should have been identified 
by the {cmdab:SMcon:textvars} utility which should be the first {cmd:stackMe} command issued by a user 
intending to employ {cmd:stackMe} to reorganize what is still a conventional Stata .dta dataset. See under 
{help stackme##Quickstart:Quickstart} in the {cmd:stackMe} help text for details.{p_end}
{synopt :{opt stackid(varname)}}{bf:THERE IS NO SUCH OPTION} for any {cmd:stackMe} command. When the data are 
stacked {cmdab:genst:acks} will supply a {cmd:stackMe} variable, {it:{cmd:SMstkid}}, that will identify each 
stack with a sequential ID number, starting at 1 and running up to the number of stacks.
(see {help genstacks##Generatedvariables:Generated variables}, below).{p_end}
{synopt :{opt ite:mname(varname)}}If available to supplement the {cmdab:genst:acks}-generated {it:{cmd:SMstkid}} 
variable for linking battery items with stack-level data. The named variable will be added to those being 
reshaped.{p_end}
{synopt :{opt noc:heck}}Do not check for batteries of equal size in each context.{p_end}
{synopt :{opt kee:pmisstacks}}Keep stacks consisting only of missing values (by default these are dropped).{p_end}
{synopt :{opt lim:itdiags(#)}}Limit displayed diagnostics to those deriving from the first # contexts (default 
is to produce diagnostics for all contexts).{p_end}
{synopt :{opt no:diagnostics}}Equivalent to limitdiags(0).{p_end}

{synoptline}


{marker Description}
{title: Description}

{pstd}
{cmd:genstacks} {help reshape}s the current dataset to a stacked (what Stata calls "long") format 
for further analysis.{p_end}
                                       Long      
                                   +–––––––––––+
            Wide                   | i  j  plr |       Reshaping left-right position (plr) of
   +–––––––––––––––––––+           |–––––––––––|      political parties from "wide" to "long"
   | i  plr1 plr2 plr3 |           | 1  1  4.1 |      format. Note that what, in wide format,
   |–––––––––––––––––––|   stack   | 1  2  4.5 |      was a numeric suffix to the 'plr' stub  
   | 1   4.1  4.5  6.5 |  ––––––>  | 1  3  6.5 |      becomes, in long format, a variable 'j'
   | 2   3.3  3.0  4.4 |           | 2  1  3.3 |      and values of plr are stacked on top of
   +–––––––––––––––––––+           | 2  2  3.0 |      each other instead of being listed next 
                                   | 2  3  4.4 |      to each other. The unit identifier 'i' 
                                   +–––––––––––+      is repeated for each j.

{smcl}
{pstd}
Sets of variables (aka batteries), each battery consisting of variables named by adding a numeric 
suffix to one of the identifying stubs that might otherwise be specified in {help:varlist:namelist} (in 
Syntax 2), will be reshaped into what Stata 
calls a "long" format (see {help reshape:reshape}). Suffixes identifying the individual variables in 
each set are retained as stack identifiers in the reshaped data. Typically these are numbers running 
from 1 to the number of variables in the set. However Stata's {cmdd:reshape} (invoked by {cmdab:genst:acks}) 
permits variables to be omitted if the corresponding item (eg. political party) is missing in some contexts, 
in which case variables omitted from a battery are treated as though a variable had been supplied whose 
values were all missing. The numeric suffixes are retained as identifiers for each stack (each row in the 
reshaped data) and held in the generated variable {it:{cmd:SMstkid}}. Command {cmdab:genst:acks} permits 
the user to name a linkage variable (using option {opt ite:mname}) whose values provide a supplementary 
means of identifying each stack.{break}

{pstd}To be clear, there is one stack (row) in the stacked battery for each variable (column) in the 
unstacked battery; the generated variable {it:{cmd:SMstkid}} contains, for each stacked row (each so-called 
"stack"), the numerical suffix associated with the corresponding unstacked column.{break}

{pstd}All other variables (those not identified by battery {varlist}s in Syntax 1 or by corresponding 
stubnames in syntax 2) are duplicated onto all stacks associated with a specific unit (observation), 
filling out the stacked data matrix with these duplicates (it is advisable to drop unwanted variables before 
stacking as the dataset can expand up to K-fold, where K is the largest {it:{cmd:SMstckid}} value found in 
any battery).{break}

{pstd}
{bf:IT IS IMPORTANT} to keep track of whether your dataset is stacked or not and, if stacked, what 
is the "stack identification variable" – see below). We recommend you stack your data using 
{help stackMe}'s {help genstacks:{ul:genst}acks} command (the command documented here), which will help with 
this task in a number of ways, and that you not change the names of variables created by {cmdab:genst:acks} 
(all starting with the letters SM) in pursuit of this goal. {cmdab:genst:acks} will suggest an 
appropriate filename (the original name preceeded by the characters "STKD_") for any dataset it 
{help reshape}s, distinguishing it as such. Similarly, the names of variables stacked by {cmdab:genst:acks} 
will have the characters "Stkd" (or "S2kd" if doubly-stacked) prepended to their names.{p_end}

{marker Watershed}{pstd}{cmd:genstacks} constitutes something of a watershed within the {cmd:stackMe} 
package, since it reshapes the data from having a single stack per unit (observation) to having 
multiple stacks per unit. No provision is made within {cmd:stackMe} for unstacking a dataset once it 
has been stacked, but other stackMe commands can be used with either stacked or unstacked data. 
Stata's {bf:reshape} command can be used (taking advantage of the generated variable {it:{cmd:SMunit}}  
to switch back to "wide" format, but the result may not reproduce exactly the same dataset as the one 
that was stacked, because of changes outlined above.{break}

{pstd}See {cmd:stackMe}'s help text for a description of the {help stackMe##Workflow:workflow} 
inherent in these commands.

{pstd}
SPECIAL NOTE ON MULTIPLE BATTERIES. Data to be stacked often consists of multiple batteries of variables that 
were asked regarding the same objects. In the disciplines for which stackMe was originally designed those 
objects would generally be either political parties or political issues; but other relevant objects such as 
schools or manufacturers or hospitals readily come to mind. The important thing in regard to stacking 
the data for such objects is that each battery of variables (variables resulting from questions about the 
same battery topic) {ul:must} relate to the {ul:same} objects. Batteries of questions regarding other 
objects would need to be stacked separately (see {cmd:stackMe}'s introductory {help stackMe}, especially 
regarding {help stackme##Doublydtackeddata:double-stacking}).{p_end}
{pstd}
{space 3}{cmd:genstacks} identifies the items in a battery with variable names consisting of a "stub" string 
of text that is the same for all variables in a battery, but with numeric suffixes appended to that stub that 
identify the object (party or school or manufacturer or hospital, etc.) about which those questions were asked. 
It is thus essential that those numeric suffixes consistently relate to the same objects for each separate battery. 
However {cmdab:genst:acks} cannot check that these numeric suffixes are correct. It is important to be aware that, 
in datasets emanating from election studies (and perhaps elsewhere), it is quite common for some questions 
(e.g. about party stances on certain issues) to be asked only for a subset of the objects being investigated 
(eg. parties). Moreover, those objects and questions relating to those objects may not always be listed in the 
same order with consistent question numbers. So relying on the relative position of each item to retain the same 
meaning across batteries may lead to grievous errors. Command {cmd:stackMe} can alleviate one aspect of this 
problem if the user employs {cmd:stackme}'s {help gendummies:{ul:gendu}mmies}, in preference to Stata's 
{help tab1}, to generate batter(ies) of dummy variables identified according to values actually found in the 
data rather than according to the sequential order of those values. But those values do need to be correct, 
which only the user can check. See also the special note on reference values in the help text for 
{help gendist:{ul:gendi}st}.



{title:Options}
{synoptset}
{synopthdr:Options}
{synoptline}

{phang}
{opt con:textvars(varlist)} {bf:THERE IS NO SUCH OPTION} for command {cmdab:genst:acks}. The variables 
identifying different contexts within which batteries will be separately reshaped should have been identified 
by the {help contextvars:{ul:SMcon}textvars} command which should be the first {cmd:stackMe} command issued by 
a user intending to employ {cmd:stackMe} commands with what is still a conventional Stata .dta dataset. See under 
{help stackme##Quickstart:Quickstart} in the help text for {cmd:stackMe} for details.{p_end}

{phang}
{opt ite:mname(name)} if available. The name of a variable that supplements the {cmdab:genst:acks}-generated 
{it:{cmd:SMstkid}} and {it:{cmd:S2stkid}} variables (see {help genstacks##Generatedvariables:below}) for linking 
{help stackMe##Datastacking:battery} data with stack-level data. The data values for this variable should be 
codes that uniquely identify each individual stack across all contexts: codes that might, for example, identify 
appropriate Stata value labels naming each stack within all contexts. That real variable will be added to those 
being reshaped by {cmdab genst:acks}, often providing a key for merging additional variables to the stacked 
data (variables found in expert surveys or archives of party platforms/manifestos, for instance). The variable 
name provided by this option is kept in a data characteristic named either {it:{cmd:SMitem}} or {it:{cmd:S2item}}, 
depending on whether {cmdab:genst:acks} is undertaking a conventional (first-stage) stacking operation or whether the 
operation is a second-stage {help stackme##Doublydtackeddata:double-stacking} of the data. The link to an alternative 
set of values that uniquely identify the same stacks is provided for convenience and to ensure that such linkage variables 
are appropriately reshaped. Occasionally there may be additional linkage variables that will need to be reshaped by being 
included as additional batteries among those in a {cmdab:genst:acks} {varlist} or implied by a {cmdab:genst:acks} namelist 
(see above). It will be up to the user to keep track of any such variables, reshaping them as needed and documenting their 
usage with appropriate variable labels. NOTE that the labels and values linked to by {it:{cmd:SMitem}} will be applied to 
all variables stacked by the same {cmdab genst:acks) command, so it is well worth the trouble of labeling the categories of 
such a variable. {it:{cmd:SMitem}} and {it:{cmd:S2item}} can be temorarily renamed by employing the {opt ite:mname(name)} 
option fpr any {cmd:stackMe} command that offers such an option (all except {cmdab:gendummies}). The associated variable 
named in the relevant characteristic can be changed or cleared by {cmd:stackMe}'s {cmdab:SMite:mname} utility or its 
counterpart for doubly-stacked data.{p_end}

{phang}
{opt rep:lace} ensures that all original batteries of variables, identified as such in a Syntax 1 {cmdab:gendi:st} 
command or implied by the stubs listed in a Syntax 2 {cmdab:gendi:st} {it:namelist}, are be dropped after stacking, 
saving considerable filespace and somewhat reducing execution time. The default is to keep all original variables 
on grounds that it is hard to be sure they will never be needed. See the helpfile for {help genplace:{ul:genpl}ace} 
for examples of variables that need to be retained in their original form after stacking.{p_end}

{phang}
{opt noc:heck} skips the check for batteries of equal size within context, made by default, in case that check is 
meaningful in particular dtasets. The check will not be meaningful in many circumstances where the data are 
nevertheless coherent and consistent (for example because a battery question was omitted from the questionnaire 
fielded in a country where that question was not meaningful for a given battery item.)

{phang}
{opt kee:pmisstacks} cancels default treatment of dropping stacks with all-missing values, saving (sometimes considerable) 
filespace for the resulting stacked dataset. Note that the numbering of stacks held in variable {it:{cmd:SMstkid}} remains 
unchanged when missing stacks are dropped.

{phang}
{opt lim:itdiag(#)} supresses warning messages for batteries with unequal #s of vars and messages reporting progress 
through stacking stages after processing # batteries.{p_end}

{phang}
{opt nod:iagnostics} equivalent to {opt limitdiag(0)}.{p_end}

{p 4 4}Specific options all have default settings, but option {opt rep:lace} is commonly employed to remove 
variables that are redundant after stacking (which they are not if {cmd:stackMe}'s command {help genplace} 
is to be employed}.{p_end}



{title:Examples}

{phang2}{cmd:. genstacks rsym1-rsym7 || rsyml1-rsyml7 || lrdpty1-lrdpty7,}{cmd: replace}{p_end}

{pstd}Reshape three batteries of items, involving sympathy for parties, sympathy for party 
leaders, and left-right distances from the same 7 parties. The only option directs that the 
originals of reshaped variables be dropped. Note that, with this syntax, if some variables 
are missing from certain contexts the user will need to respond to a relevant warning.{p_end} 

{phang2}{cmd:. genstacks rsym rsyml lrdpty, replace}{p_end}

{pstd}Achieves exactly the same result as the first example but with less typing and avoiding 
the risk that some of the variables might not be present in all contexts. Indeed this is the 
command created internally by {cmd: genstacks}, translating the first format into the (less 
risky) second syntax (and warning the user if the two do not match).{p_end}


{marker Generatedvariables}
{title:Generated variables}

{p2colset 4 14 14 2}{...}
{synopt:{it:SMstkid}}a generated variable identifying each primary stack in a conventionally 
stacked dataset. It is recommended that the name of this variable not be changed. The variable 
label for this variable lists the stubnames corresponding to batteries of variables that were 
stacked by the same {cmdab genst:acks} command. These names are also known as "battery names" 
or "stacknames". The order of these names is the same as the order in which stubnames were 
presented in the command's varlist or namelist. If one of the batteries has some sort of 
logical priority (perhaps being expected to serve as a {depvar} for other batteries in the 
stacked data) then, for documentary purposes, that battery should be the first battery (or 
provide the first stubname) in the {cmdab genst:acks} {varlist} or {namelist}.{p_end}

{synopt:{it:S2stkid}}a generated variable identifying each secondary stack in a 
{help stackme##Doublydtackeddata:doubly-stacked} dataset. It is recommended that the name of this 
variable not be changed. Stubnames for doubly-stacked data do not have numeric suffixes (since 
they are stack-names not variable names). {cmdab genst:acks} instead checks that all the 
named variables listed in the commandline are contained in the list of stubnames contained in 
the first-stage {it:{cmd:SMstkid}} generated variable (see above).{p_end}

{synopt:{it:SMunit}}a generated variable identifying the overall unit number (might correspond 
to a respondent ID) uniquely identifying the units that were observations before stacking. This 
identifier will be required if ever a user wants to unstack a dataset using Stata's {help reshape} 
{bf:wide} command. It is recommended that this variable name not be changed.{p_end}

{synopt:{it:SMnstks}}a generated variable identifying, for each context in a conventionally stacked 
dataset, the maximum number of stacks in the battery after stacking (which is also the number of 
variables in the battery before stacking) – often more than the number stacks in certain contexts if 
some of those stacks are entirely missing in those contexts) and hence dropped from the portion of 
the stacked dataset relating to that context.{p_end}

{synopt:{it:SMitem}}a quasi-variable that takes up no space in the dataset but, instead, points to 
(one could say it is "linked" to) a real variable whose name it stores as a "characteristic" (an 
obscure feature of Stata datasets). When this quasi-variable is named in a {cmd stackme} {varlist} 
the varlist name will be changed internally to the name of the real variable that will be treated 
exactly as though it was the variable named by the user.

{p 3 3}{cmd:NOTE:} When double-stacking a dataset, additional secondary ID vars (not shown above) 
are generated for units, items and nstacks, deriving their names just as does {it:S2stkid}. In a 
doubly-stacked dataset, by default the two {it:{cmd:stkid}} variables will be used in conjunction 
to identify the combination of stacks defining each doubly-stacked unit. But the user can override 
and clarify this default by using option {opt ite:mname} (see above) to name a variable (perhaps 
present in the original data, perhaps specially {help generate}d by the user) that uniquely 
identifies individual stacks across the entire doubly-stacked dataset. Command {cmdab:genst:acks} 
determines whether to doubly-stack the data based on whether the data are already stacked and the 
manner in which the {opt S2u:nit} option is operationalized takes account of the same 
considerations.{p_end}
