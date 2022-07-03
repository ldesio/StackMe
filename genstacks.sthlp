{smcl}
{cmd:help genstacks}
{hline}

{title:Title}

{p2colset 5 20 22 2}{...}
{p2col :genstacks {hline 2}}Stacks a dataset for analysis in reshaped (long) format{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 16 2}
{opt genstacks} {namelist}
   [{cmd:,} {it:options}]

{synoptset 22 tabbed}{...}
{synopthdr}
{synoptline}
{synopt :{opth con:textvars(varlist)}}the variables identifying different electoral contexts 
(leave unspecified for conventional datasets with only one context){p_end}
{synopt :{opt rep:lace}}drops original variable sets after reshaping them{p_end}
{synopt :{opth uni:tname(name)}}provides a variable name for the generated variable 
identifying the unit of analysis (default is _genstacks_respid){p_end}
{synopt :{opth sta:ckid(name)}}provides a variable name for the generated variable 
identifying each specific stack in the reshaped dataset (default is _genstacks_stack){p_end}
{synopt :{opth ite:mname(name)}}provides a variable name for the generated variable 
identifying the original item number before reshaping (default is _genstacks_item){p_end}
{synopt :{opth tot:stackname(name)}}provides a variable name for the generated variable 
containing the total number of stacks found for each context(default is _genstacks_totstacks){p_end}
{synopt :{opth fe(namelist | _all)}}designates the variable(s) among reshaped stubs 
to be provided with corresponding fixed effects{p_end}
{synopt :{opth fep:refix(name)}}provides a prefix  to prepend the names of variables 
that hold fixed effects for variable(s) named by each suffix (default is fe_){p_end}

{synoptline}

{title:Description}

{pstd}
{cmd:genstacks} reshapes the current dataset to a stacked format for further analysis.{break}

{pstd}Sets of variables (aka batteries), each set identified by one of the stubs specified in 
{it:namelist}, will be reshaped into what Stata calls a 'long' format (see {help reshape:reshape}). 
Suffixes identifying the individual variables in each set are retained as item identifiers 
in the reshaped data. By default, suffixes must be identical for each set of variables - typically 
these are numbers running from 1 to the number of variables in the set. However Stata's {cmd:reshape} 
permits any numeric suffixes so long as each suffix is unique. This permits variables to be 
omitted if the corresponding item (eg political party) is missing in some contexts, in which 
case variables omitted from a battery will be stacked as though a variable had been supplied 
whose values were all missing. {cmd:genstacks} generates a variable (named by option {bf:itemname)}) 
whose suffixes identify the suffixes actually found. An additional variable (named by option 
{bf:stackid} numbers each stack sequentially. {break}

{pstd}All other variables (those not identified by stubs in {it:namelist}) are copied onto all stacks 
(it is advisable to drop unwanted variables before stacking as the dataset expands K-fold 
where K is the number of variables in the battery). If the {cmd:contextvars} option is specified, 
the procedure is applied separately to each context identified by {cmd:contextvars}. Typically 
these will be different countries, or the same countries in different years.{break}

{pstd}{cmd:genstacks} constitutes something of a watershed within the {cmd:stackMe} package, 
since it reshapes the data from having a single stack per case to having multiple stacks 
per case. No provision is made within {cmd:stackMe} for unstacking a dataset once it has been 
stacked, but other stackMe commands can be used with either stacked or unstacked data. Stata's 
{bf:reshape} command can be used to switch back to "wide" format, but the result will not 
reproduce exactly the same dataset as the one that was stacked because of changes outlined 
above.{break}

{pstd}See {help staceMe:stackMe} for a description of the workflow inherent in these commands.

{pstd}
SPECIAL NOTE ON MULTIPLE BATTERIES. {cmd:genstacks} identifies the items in a battery with corresponding 
variables by means of the numeric suffix appended to the stubname for each battery. It is thus essential 
that these numeric suffixes relate to the same objects for each battery. However {cmd:genstacks} cannot 
check that the numeric suffixes are correct. It is important to be aware that, in datasets emanating 
from election studies, it is quite common for some questions (eg about party locations on certain 
issues) to be asked only for a subset of the objects being investigated (eg parties). Moreover, those 
objects and questions relating to those objects may not always be listed in the same order. So counting 
on the relative position of each item to retain the same meanings across batteries may lead to grievous 
errors. However, {cmd:stackMe} can alleviate one aspect of this problem if the user employs {cmd:gendummies} 
in preference to {cmd:tab1} to generate batter(ies) of dummy variables based on questions that did
not list all items or listed them in a different order than elsewhere in the data. But those values 
do need to be correct, which only the user can check. See also the special note on multiple batteries 
in the help text for {bf:{help gendist:gendist}}.


{title:Options}

{phang}
{opt contextvars(varlist)} (if specified) the variable(s) whose (combinations of) values 
identify different electoral contexts (eg. countries, years). The default is to assume all 
cases fall within a single context.

{phang}
{opt unitname(name)} (if specified) name to be given the variable Stata calls the 'i' variable 
(see {help reshape:reshape}), created internally by {cmd:genstacks}, identifying the unit of analysis 
in the original (unreshaped) data (default is _genstacks_unit). In comparative electoral research this 
might be the respondent ID.

{phang}
{opt replace} (if specified) ensures that all original sets of variables identified by the stubs listed 
in {it:namelist} will be dropped.

{phang}
{opt stackid(name)} (if specified) provides a variable name for the generated variable 
identifying each specific stack (default is _genstacks_stack which is the default variable 
name expected by {cmd:genyhats}, {cmd:genimpute} or {cmd:gendist} if these are invoked after 
stacking.{p_end}

{phang}
{opt itemname(name)} (if specified) provides a variable name for the generated variable 
identifying the original item (default is _genstacks_item). This is the variable Stata 
Refers to as the `j' variable (see {help reshape:reshape}). The difference between the 
{it:item} and {it:stackid} variables emerges when non-consecutive items are found 
in the original set of variables, e.g. if parties in a battery are party1, party3, party7. 
In this case, stacks will be numbered 1,2,3, while items will be numbered 1,3,7, 
to preserve the connection with the unstacked data.{p_end}

{phang}
{opt totstackname(name)} (if specified) a variable name for the generated variable 
containing the total number of stacks in each context (default is _genstacks_totstacks). 
Evidently this cannot be more than the number of variables in {it:namelist} but may
be less for specific contexts - for example if the contexts are countries that have 
different party systems.{p_end}

{phang}
{opt fe(namelist | _all)} (if specified) the variable(s) among reshaped stubs 
that are to be provided with corresponding fixed effects.{p_end}

{phang}
{opt feprefix(namel)} (if specified) a prefix  (default is fe_) that prepends the names 
of any variables that hold fixed effects for corresponding variable(s) named by each 
suffix.{p_end}

{title:Examples:}

{pstd}
The following command stacks a dataset where observations are nested in contexts defined 
by {it:cid}; variable sets {it:i_sympathy*} and {it:i_lrd*} will be stacked into new variables 
{it:i_symp} and {it:i_lrd}, with the original variables dropped. All other variables 
in the dataset are duplicated across the k records for each case created by reshaping 
the k variables in each set.{p_end}{break}
{phang2}
{cmd:. genstacks i_sympathy i_lrp, contextvars(cid) replace}{p_end}

{pstd}
NOTE that {it:i_ptv} and {it:i_lrp} in the above command are stubnames, not variable lists. 
The use of {it:i_ptv*} or {it:i_lrd1-i_lrd10} in this command would cause an error. The 
{it:i_} prefix used in these stubnames suggests that this command follows 
the use if {bf:{help gen:impute} to impute missing data for the variables indicated 
by each stubname. These stubs become the names of the reshaped variables.{p_end}


{title:Generated variables}

{pstd}
{cmd:genstacks} saves the following variables and variable sets:

{synoptset 21 tabbed}{...}
{synopt:name [name]...} the variables named by the stubs specified in {it:namelist} 
(originals left unchanged unless {cmd:replace} is optioned).{p_end}
{synopt:_genstacks_stack} (or other name defined in option {bf:stackname}) 
a variable identifying the k different rows (stacks) generated by reshaping 
the k different items in each set named in {it:namelist} (ID numbers are consecutive).{p_end}
{synopt:_genstacks_item} (or other name defined in option {it:itemname}) 
a variable identifying the k different items before stacking 
(need not be consecutive but must be the same for each set of items).{p_end}
{synopt:_genstacks_totstacks} (or other name defined in option {it:totstackname}) 
a variable giving the number of rows (stacks) for each unstacked case (respondent) 
in each context after reshaping.{p_end}
{synopt:fe_{it:name} [fe_{it:name}]...} (or other prefix defined in option {bf:feprefix}) 
the variables holding fixed effects versions of (reshaped) stubs, if optioned.{p_end}
