{smcl}
{cmd:help genstacks}
{hline}

{title:Title}

{p2colset 5 18 18 2}{...}
{p2col :genstacks {hline 2}}Stacks a dataset for analysis in {help reshape}d (long) format (read StackMe's 
{help stackme##Datastacking:Data stacking} help-text before proceeding){p_end}
{p2colreset}{...}


{title:Syntax}

{p 6 14 2}
{opt genst:acks} unstacked_{varlist} [ {bf:||} {varlist} {bf:||}  ... ]{cmd:,} {it:options}

	or

{p 6 14 2}
{opt genstacks} stacked_{it:{help namelist}}{cmd:,} {it:options} 


{p 2 2 2}where {varlist} in syntax 1 lists the names of variables constituting one or more 
{it:batter(ies)} of items, each battery delimited by "||", whereas {it:namelist} in syntax 
2 lists the textual "stubs" that will name the same variables after reshaping – one stub for 
each "||"-delimeted list of battery-members. Using syntax 2 is especially advantageous when 
batteries have different numbers of items in different contexts.

{p 2 2 2}
Stubnames must be the same for all variables in a battery. If a battery's 
variables do not have consistent stubnames with numeric suffixes then they need 
to be {help rename}d before invoking {cmd:genstacks}. See {help rename group}, especially rule 17.

{p 2 2 2}
{cmd:genstacks} does not support [if][in] or [weight] expressions. Reshaping applies to the entire 
dataset as it stands when reshaped.

   
{synoptset 22 tabbed}{...}
{synopthdr}
{synoptline}
{synopt :{opth con:textvars(varlist)}}(generally required) the variables identifying different 
electoral contexts (leave unspecified only for conventional dataset with just one context){p_end}
{synopt :{opth sta:ckid(name)}}(default is SMstkid) name to be given to a generated variable 
recording the sequential position of what had, before stacking, been individual battery-items{p_end}
{synopt :{opth ite:mname(name)}}(required if different from the {opt sta:ckid} variable)
name of an existing variable identifying, for each stack, what had before stacking been individual 
battery-items{p_end}
{synopt :{opth uni:tname(name)}}(default is SMunit}) name to be given to a generated variable 
identifying each original unit (often the respondent to a sample survey) in the data before stacking.{p_end}
{synopt :{opt noc:heck}}Do not check for batteries of equal size.{p_end}
{synopt :{opt kee:pmisstacks}}Keep stacks consisting only of missing values (by default these are 
dropped).{p_end}
{synopt :{opth fe(namelist | _all)}}designates the variable(s) among reshaped stubs 
to be provided with corresponding fixed effects{p_end}
{synopt :{opth fep:refix(name)}}provides a prefix  to prepend the names of variables 
that hold fixed effects for variable(s) named by each suffix (default is fe_){p_end}
{synopt :{opth lim:itdiags(#)}}Limit displayed diagnostics to those deriving from the first 
# batteries.{p_end}
{synopt :{opt nod:iagnostics}}Equivalent to limitdiags(0){p_end}

{synoptline}


{title:Description}

{pstd}
{cmd:genstacks} {help reshape}s the current dataset to a stacked (what Stata "long") format for 
further analysis.

{pstd}
{bf:IT IS IMPORTANT} to keep track of whether your dataset is stacked or not and, if stacked, what 
is the "stack identification variable" ({help stackid} – see below). We recommend you name 
the stack id at the start of the {help data label} for any dataset that is stacked. The {cmd:StackMe} 
command {help genstacks} will suggest an appropriate data label for any dataset it {help reshape}s; 
but it is up to the user to copy and paste that label into the Stata command window where it can be 
edited as desired before being <return>ed.{p_end}

{pstd}
Sets of variables (aka batteries), each battery consisting of variables named by adding a numeric 
suffix to one of the identifying stubs that might otherwise be specified in {it:namelist} (in 
Syntax 2), will be reshaped into what Stata 
calls a "long" format (see {help reshape:reshape}). Suffixes identifying the individual variables in 
each set are retained as item identifiers in the reshaped data. By default, suffixes must be identical 
for each set of variables - typically these are numbers running from 1 to the number of variables in 
the set. However Stata's {cmd:reshape} (invoked by {cmd:genstacks}) permits any numeric suffixes so 
long as each suffix is unique. This allows variables to be omitted if the corresponding item (eg. 
political party) is missing in some contexts, in which case variables omitted from a battery will 
be treated as though a variable had been supplied whose values were all missing. Command {cmd:genstacks} 
generates a variable (named by option {opt ite:mid)}) whose values are the values actually 
found. An additional variable (named by option {opt sta:ckid}) numbers each "stack" (the name given 
to a row that results from {help reshape}ing a dataset into long format). These stacked numbers are 
sequential, running from 1 to the number of stacks.{break}

{pstd}To be clear, there is one stack (row) in the stacked battery for each variable (column) in the 
unstacked battery; the variable named in option {opt ite:mid} contains in each stacked row 
(each so-called "stack") the numerical suffix associated with the corresponding unstacked column.{break}

{pstd}All other variables (those not identified by battery {varlists} in Syntax 1 or by corresponding 
stubs in syntax 2) are copied onto all stacks 
(it is advisable to drop unwanted variables before stacking as the dataset expands K-fold 
where K is the largest number of variables in any battery). If the {cmd:contextvars} option is specified, 
the procedure is applied separately to each context identified by {cmd:contextvars}. Typically 
these will be different countries, or the same countries in different years.{break}

{pstd}{cmd:genstacks} constitutes something of a watershed within the {cmd:stackMe} package, 
since it reshapes the data from having a single stack per case to having multiple stacks 
per case. No provision is made within {cmd:stackMe} for unstacking a dataset once it has been 
stacked, but other stackMe commands can be used with either stacked or unstacked data. Stata's 
{bf:reshape} command can be used (taking advantage of the variable named by {cmd:genstacks}' 
{opt ite:m} option) to switch back to "wide" format, but the result will not reproduce exactly 
the same dataset as the one that was stacked, because of changes outlined above.{break}

{pstd}See {help stackMe} for a description of the workflow inherent in these commands.

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
{opt contextvars(varlist)} the existing variable(s) whose (combinations of) values identify different 
electoral contexts (eg. countries, years). The default is to assume all cases fall within a single context.

{phang}
{opt stackid(name)} (default is SMstkid) name to be given to the variable identifying different 
stacks.

{phang}
{opt unitname(name)} name to be given the variable Stata calls the 'i' variable, running from 
1 to the N of cases in the entire dataset over all contexts before stacking (see {help reshape:reshape}), 
created internally by {cmd:genstacks} and identifying the unit of analysis in the original 
(unreshaped) data (default is stackme_unit. This ID is required for unstacking 
the data using Stata's {help reshape wide} (but see limitations mentioned 6 paragraphs above). 
It must exist as a variable with the same list of numeric suffixes as other variables to be stacked.

{phang}
{opt itemmame(name)} Names an existing variable that identifies 
the original battery item corresponding to different stacks. This is the variable Stata 
Refers to as the `j' variable (see {help reshape:reshape}). The difference between the 
{it:item} and {it:stackid} variables emerges when non-consecutive items are found 
in the original set of variables. For example, if parties in a battery have IDs 7101, 7103, 
7109, stacks will be numbered 1 2 3 while items will be numbered 7101 7103 7109, So, in 
The stacked dataset both IDs are needed in order to preserve the connection with the 
unstacked data.{p_end}

{phang}
{opt replace} ensures that all original batteries of variables, identified by the stubs listed in 
{it:namelist}, will be dropped, saving considerable filespace (default is to keep all original variables).

{phang}
{opt nocheck} skips the check for batteries of equal size, made by default. 

{phang}
{opt keepmisstacks} cancels default treatment of dropping stacks with all-missing values, 
saving (sometimes considerable) filespace for the resulting stacked dataset. Note that the 
numbering of stacks remains unchanged when missing stacks are dropped.

{phang}
{opt fe(namelist | _all)} the variable(s) among reshaped stubs 
that are to be provided with corresponding fixed effects.{p_end}

{phang}
{opt feprefix(namel)} a prefix  (default is fe_) that prepends the names 
of any variables that hold fixed effects for corresponding variable(s) named by each 
suffix.{p_end}

{phang}
{opt limitdiag(#)} suppresses warning messages for batteries with unequal #s of vars and 
messages reporting progress through stacking stages after processing # batteries.{p_end}

{phang}
{opt nod:iagnostics} equivalent to {opt limitdiag(0)}.{p_end}

{p 4 4}Specific options all have default settings, but option {opt con:textvars} is required 
for multi-level datasets – the datasets for which {help StackMe} commands are intended) – 
and {opt rep:lace} is commonly employed to remove variables that are redundant after 
stacking.


{title:Examples}

{phang2}{cmd:. genstacks rsym1-rsym7 || rsyml1-rsyml7 || lrdpty1-lrdpty7,}
{cmd: context(country year) itemname(origid)}{p_end}

{pstd}Reshape three batteries of items, involving sympathy for parties and for party 
leaders and left-right distances from the same 7 parties. Context identifiers are provided (country 
and year) along with an item identifying the original code for each individual battery member, 
implying that these codes are not 1-7.{p_end} 

{phang2}{cmd:. genstacks rsym rsyml lrdpty, context(country year) itemname(origid)}{p_end}

{pstd}Achieves exactly the same result as the earlier example but with less typing and avoiding 
the risk that some of the variables might not be present in all contexts. Indeed this is the 
command created internally by {cmd: genstacks}, translating the first format into the (less 
risky) second syntax{p_end}


{title:Generated variables}

{p2colset 4 14 14 2}{...}
{synopt:{it:SMstkid}}the generated variable identifying different stacks. It is 
recommended that the name of this variable not be changed.{p_end}

{synopt:{it:SMunit}}the generated variable identifying the overall unit number (generally 
respondent number) uniquely identifying all units across stacks and contexts. This identifier 
will be required if ever a user wants to unstack a dataset using Stata's {help reshape wide} 
command. It is recommended that neither this variable name nor the record of this name kept 
in the data label of a dataset stacked by {cmd:genstacks} be changed.{p_end}

{synopt:{it:SMtotstks}}the generated variable identifying, for each context, the number of 
cases (stacks) used to hold different battery-members after stacking (often less than the number 
of different battery members before stacking if some of these are entirely missing for in some 
contexts). This name is not kept in the datalabel as it is easily reconstructed by using the 
stata {help egen} command {cmd: egen SMtotstks = count(SMstkid), by {it:contextvars}}.{p_end}

{synopt:{it:SMitemname}} The name of the variable identifying the original battery items 
corresponding to each stack, if this is not the same as the stackid. The name if this variable 
is kept in the first word of the stackMe data label. It is recommended that the name not be 
changed.{p_end}

{p 3 3}
If you wish to change these names, or if you want to use a stacked dataset that was not stacked 
by StackMe's {cmd:genstacks} command, we recomment you employ the StackMe utility command {help genid}.




