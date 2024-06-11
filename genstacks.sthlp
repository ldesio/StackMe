{smcl}
{cmd:help genstacks}
{hline}

{title:Title}

{p2colset 5 18 18 2}{...}
{p2col :genstacks {hline 2}}Stacks a dataset for analysis in {help reshape}d (long) format (be sure 
you are familiar with concepts introduced in StackMe's {help stackme##Datastacking:Data stacking} 
help-text before proceeding){p_end}
{p2colreset}{...}


{title:Syntax}

{p 6 14 2}
{opt genst:acks} unstacked_{varlist} [ {bf:||} {varlist} {bf:||}  ... ]{cmd:,} {it:options}

	or

{p 6 14 2}
{opt genstacks} stacked_{it:{help namelist}}{cmd:,} {it:options} 


{p 2 2 2}where {varlist} in syntax 1 lists the names of variables constituting one or more 
{it:batter(ies)} of items, each battery delimited by "||", whereas {it:namelist} in syntax 
2 lists the textual "stubs" that will name the same variables after reshaping – one stub in 
Syntax 2 for each varlist in syntax 1. So syntax 2 involves less typing and provides less 
opportunity for error.

{p 2 2 2}
Stubnames must be the same for all variables in a battery. If a battery's 
variables do not have consistent stubnames with numeric suffixes then they need 
to be {help rename}d before invoking {cmd:genstacks}. See {help rename group}, especially rule 17.

{p 2 2 2}
{cmd:genstacks} does not support [if][in] or [weight] expressions. Reshaping applies to an entire 
dataset as it stands when reshaped.

   
{synoptset 22 tabbed}{...}
{synopthdr}
{synoptline}
{p2colset 5 26 28 2}
{synopt :{opt con:textvars(varlist)}}(generally required) the variables identifying different 
contexts within which batteries will be separately reshaped (leave unspecified only for conventional 
dataset with just one context).{p_end}
{synopt :{opt ite:mname(varname)}}If needed to supplement the {cmdab:genst:acks}-generated {it:{cmd:SMstkid}} 
variable for linking battery data with stack-level data. Variable will be added to those being reshaped.{p_end}
{synopt :{opt noc:heck}}Do not check for batteries of equal size in each context.{p_end}
{synopt :{opt kee:pmisstacks}}Keep stacks consisting only of missing values (by default these are 
dropped).{p_end}
{synopt :{opt lim:itdiags(#)}}Limit displayed diagnostics to those deriving from the first 
# contexts (default is to produce diagnostics for all contexts).{p_end}
{synopt :{opt no:diagnostics}}Equivalent to limitdiags(0).{p_end}

{synoptline}


{title:Description}

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
{bf:IT IS IMPORTANT} to keep track of whether your dataset is stacked or not and, if stacked, what 
is the "stack identification variable" – see below). We recommend you stack your data 
Using {help stackMe}'s {help genstacks} command (the command documented here), which will help with 
this task in a number of ways, and that you not change the names of variables created by {cmd:genst:acks} 
(all starting with the letters SM) in pursuit of this goal. {cmd:genstacks} will suggest an 
appropriate data label for any dataset it {help reshape}s, which the user can copy and paste (between 
double-quotaton marks) into the Stata command window where it can be edited as desired before being 
<return>ed (<enter>ed).{p_end}

{pstd}
Sets of variables (aka batteries), each battery consisting of variables named by adding a numeric 
suffix to one of the identifying stubs that might otherwise be specified in {it:namelist} (in 
Syntax 2), will be reshaped into what Stata 
calls a "long" format (see {help reshape:reshape}). Suffixes identifying the individual variables in 
each set are retained as stack identifiers in the reshaped data. Typically these are numbers running 
from 1 to the number of variables in the set. However Stata's {cmd:reshape} (invoked by {cmd:genstacks}) 
permits variables to be omitted if the corresponding item (eg. 
political party) is missing in some contexts, in which case variables omitted from a battery are 
treated as though a variable had been supplied whose values were all missing. The numeric suffixes 
are retained as identifiers for each stack (each row in the reshaped data) and held in the generated 
variable {it:{cmd:SMstkid}}. Command {cmdab:genst:acks} permits the user to name a variable (using option 
{opt ite:mid)}) whose values provide a supplementary means of identifying each stack.{break}

{pstd}To be clear, there is one stack (row) in the stacked battery for each variable (column) in the 
unstacked battery; the generated variable {it:{cmd:SMstkid}} contains, for each stacked row (each so-called 
"stack"), the numerical suffix associated with the corresponding unstacked column.{break}

{pstd}All other variables (those not identified by battery {varlist}s in Syntax 1 or by corresponding 
stubnames in syntax 2) are duplicated onto all stacks, filling out the stacked data matrix with these 
duplicates (it is advisable to drop unwanted variables before stacking as the dataset can expand up to 
K-fold, where K is the largest {it:{cmd:SMstckid}} value found in any battery).{break}

{marker Watershed}{pstd}{cmd:genstacks} constitutes something of a watershed within the {cmd:stackMe} 
package, since it reshapes the data from having a single stack per unit (observation) to having 
multiple stacks per unit. No provision is made within {cmd:stackMe} for unstacking a dataset once it 
has been stacked, but most other stackMe commands can be used with either stacked or unstacked data. 
Stata's {bf:reshape} command can be used (taking advantage of the generated variable {it:{cmd:SMunit}}  
to switch back to "wide" format, but the result may not reproduce exactly the same dataset as the one 
that was stacked, because of changes outlined above.{break}

{pstd}See {cmd:stackMe}'s help text for a description of the {help stackMe##Workflow:workflow} 
inherent in these commands.

{pstd}
SPECIAL NOTE ON MULTIPLE BATTERIES. {cmd:genstacks} identifies the items in a battery with corresponding 
variables by means of the numeric suffix appended to the stubname for each battery. It is thus essential 
that these numeric suffixes relate to the same objects for each separate battery. However {cmd:genstacks} 
cannot check that the numeric suffixes are correct. It is important to be aware that, in datasets emanating 
from election studies (and perhaps elsewhere), it is quite common for some questions (eg. about party locations 
on certain issues) to be asked only for a subset of the objects being investigated (eg. parties). Moreover, 
those objects and questions relating to those objects may not always be listed in the same order. So relying 
on the relative position of each item to retain the same meaning across batteries may lead to grievous 
errors. Command {cmd:stackMe} can alleviate one aspect of this problem if the user employs {cmd:stackme}'s 
{cmd:gendummies}, in preference to Stata's {cmd:tab1}, to generate batter(ies) of dummy variables identified 
according to values actually found in the data rather than according to the sequential order of those values. 
But those values do need to be correct, which only the user can check. See also the special note on reference 
values in the help text for {help gendist}.


{title:Options}

{phang}
{opt con:textvars(varlist)} the existing variable(s) whose (combinations of) values identify different 
electoral contexts (eg. countries, years). The default is to assume all observations fall within a single context.

{phang}
{opt ite:mname(name)} if needed to supplement the {cmdab:genst:acks}-generated {it:{cmd:SMstkid}} 
variable for linking battery data with stack-level data. Variable will be added to those being reshaped, often 
providing a key for merging additional variables at the stack- (e.g. party-) level.{p_end}

{phang}
{opt rep:lace} ensures that all original batteries of variables, identified as such in a Syntax 1 {cmdab:gendi:st} 
command or implied by the stubs listed in a Syntax 2 {cmdab:gendi:st} {it:namelist}, will be dropped, 
saving considerable filespace and somewhat reducing execution time (default is to keep all original variables).{p_end}

{phang}
{opt noc:heck} skips the check for batteries of equal size, made by default. 

{phang}
{opt kee:pmisstacks} cancels default treatment of dropping stacks with all-missing values, 
saving (sometimes considerable) filespace for the resulting stacked dataset. Note that the 
numbering of stacks held in variable {it:{cmd:SMstkid}} remains unchanged when missing stacks are dropped.

{phang}
{opt lim:itdiag(#)} supresses warning messages for batteries with unequal #s of vars and 
messages reporting progress through stacking stages after processing # batteries.{p_end}

{phang}
{opt nod:iagnostics} equivalent to {opt limitdiag(0)}.{p_end}

{p 4 4}Specific options all have default settings, but option {opt con:textvars} is required 
for multi-level datasets – the datasets for which {help StackMe} commands are intended) – 
and {opt rep:lace} is commonly employed to remove variables that are redundant after 
stacking.



{title:Examples}

{phang2}{cmd:. genstacks rsym1-rsym7 || rsyml1-rsyml7 || lrdpty1-lrdpty7,}
{cmd: context(country year) replace}{p_end}

{pstd}Reshape three batteries of items, involving sympathy for parties and for party 
leaders and left-right distances from the same 7 parties. Context identifiers are provided (country 
and year) along with the option directing the originals of reshaped variables to be dropped.{p_end} 

{phang2}{cmd:. genstacks rsym rsyml lrdpty, context(country year) replace}{p_end}

{pstd}Achieves exactly the same result as the earlier example but with less typing and avoiding 
the risk that some of the variables might not be present in all contexts. Indeed this is the 
command created internally by {cmd: genstacks}, translating the first format into the (less 
risky) second syntax (and warning the user if the two do not match).{p_end}


{title:Generated variables}

{p2colset 4 14 14 2}{...}
{synopt:{it:SMstkid}}a generated variable identifying each primary stack in a conventionally 
stacked dataset. It is recommended that the name of this variable not be changed.{p_end}

{synopt:{it:S2stkid}}a generated variable identifying each secondary stack in a 
{help stackme##Affinitymeasures:doubly-stacked} dataset. It is recommended that the name of this 
variable not be changed.{p_end}

{synopt:{it:SMunit}}a generated variable identifying the overall unit number (might be equivalent 
to a respondent number) uniquely identifying the units that were observations before stacking. This 
identifier will be required if ever a user wants to unstack a dataset using Stata's {help reshape} 
{bf:wide} command. It is recommended that this variable name not be changed.{p_end}

{synopt:{it:SMnstks}}a generated variable identifying, for each context in a conventionally stacked 
dataset, the maximum number of stacks in the battery after stacking (which is also the number of 
variables in the battery before stacking) – often more than the number stacks in certain contexts if 
some of those stacks are entirely missing in those contexts) and hence dropped from the portion of 
the stacked dataset relating to that context.{p_end}

{synopt:{cmd:NOTE:}}in a doubly-stacked dataset, by default both {it:{cmd:stkid}} variables will be 
used in conjunction to identify the combination of stacks defining each doubly-stacked unit. But 
the user can override this default by using option {opt ite:mname} to name a variable (perhaps 
present in the original data, perhaps specially {help generate}d by the user) that identifies a 
stack-structure suited to any specific {cmd:stackMe} command. Command {cmdab:genst:acks} determines 
whether to doubly-stack the data based on whether the data are already stacked. When double-stacking 
a dataset, additional secondary ID vars are generated for units and nstacks.{p_end}
