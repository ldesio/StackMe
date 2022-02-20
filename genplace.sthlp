{smcl}
{cmd:help genplace}
{hline}

{title:Title}

{p2colset 5 17 22 2}{...}
{p2col :genplace {hline 2}}Generates a battery placement by averaging constituent item-level 
placements{p_end}
{p2colreset}{...}


{title:Syntax}

{p 6 13 0}
{opt genplace varlist [[weight]] [if]}
   [{cmd:,} {it:options}]

{synoptset 22 tabbed}{...}
{synopthdr}
{synoptline}
{synopt :{opt con:textvars(varlist)}}variables defining each context (e.g. country-year){p_end} 
{synopt :{opt sta:ckid(varname)}}identifies different "stacks" across which a mean placement will be 
generated{p_end}
{synopt :{opt upre:fix(name)}}prefix for names of generated unit-level variables (default is "m_"){p_end}
{synopt :{opt cwe:ight(varname)}}(required) name of variable holding stack weight, constant across unit-level variables{p_end}
{synopt :{opt cpr:efix(name)}}prefix for name of generated stack-level variable (default is name "cweight_"){p_end}
{synopt :{opt nor:eport}}suppress report of variables created per context{p_end}


{synoptline}

{title:Description}

{pstd}
The {cmd:genplace} command can be issued only after stacking. It places each battery associated with 
stubnames in {it:varlist} (which had become variables when they were stacked) on the same scale as 
the placements, evauations or scores measured by that battery. Command {cmd:genplace} 
generates overall (mean) placements of batter(ies) of items (e.g. political parties) separately for 
each context (if specified) by averaging the separate placements of each battery item into a (perhaps 
weighted) mean of those placements, intended to characterize the battery as such. 
   NOTE (1): If placements derive from experts, manifestos, or some other external document, they 
will be constant across units/respondents but {cmd:genplace} takes those placement scores from the 
data, the same score for each unit/respondent within each battery/stack and context, the format used 
in many comparative datasets such as the ESS and CSES. 
   NOTE (2): If placements derive from the units/respondents (potentially different for 
each unit) then {cmd:genplace} first computes (perhaps weighted) mean placements across units/
respondents before, in a second step, using those to derive the weighted battery placement.

{pstd}
SPECIAL NOTE COMPARING {help genplace:genplace} WITH {help genmeans:genmeans}: The data processing 
performed by the first step of a two-step {cmd:genplace} command (see NOTE 2 above) is 
computationally identical to that performed by command {cmd:genmeans} but conceptually very 
different. The command {cmd:genmeans} generates means for numeric variables without regard to any 
conceptual grouping of variables inherent in batteries that might contain (some of) those variables. 
It is also limited to that one function. The command {cmd:genplace} can do the same for variables 
that are conceptually connected by being members of a battery of items but then proceeds to a second 
step in which those means (or some other placement battery defined by option {bf:cweight}) are used 
to average the item placements into a (weighted) mean placement regarding the battery as a whole (for 
example a legislature placed in left-right terms according to the individual placements of parties 
that are members of that legislature, perhaps weighted by the size of each party). Use of the 
standard {bf:if} component of the {cmd:genplace} command line can focus the generic placement on 
certain members of the battery (perhaps government parties, thus producing a left-right government 
location).{break}

{title:Options}

{phang}
{opth contextvars(varlist)} if present, variables whose combinations identify different electoral 
contexts (e.g. country and year) for each of which separate placements will be generated (same 
value for all units/respondents in each context). By default all units are assumed to belong to 
the same context.

{phang}
{opth stackid(varname)} if present, a variable identifying each different "stack" (equivalent to 
the {it:j} index in Stata's {bf:{help reshape:reshape long}} command) for which placements will be 
separately generated. The default is to use the "genplace_stack" variable. NOTE: there is no {cmd:nostack} option because placements apply 
to batteries that define each stack.

{phang}
{opth mprefix(name)} if present, prefix for the {it:varlist} names of generated placement variables 
(constant across units within contexts, if any): the (perhaps weighted) means of diverse unit-level 
placements produced in the first step of a two-step {cmd:gendist} (see NOTE 2 above). (Default is 
"m_").

{phang}
{opth cprefix(name)} if present, prefix for the name of the generated generic battery placement 
variable (constant across stacks and units within contexts, if any): the c-weighted mean of diverse 
battery-level placements. This prefix defaults to the "_"-suffixed name of the cweight variable, 
if specified, or "p_" otherwise.

{phang}
{opth cweight(varname)} if present, a weight (constant across units/respondents) used to place each 
item/stack according to the placements provided by experts or other sources in (or pertaining to) 
each context. The name of this variable will be used as a prefix for a generated battery placement 
variable if the {bf:cprefix} option is not specified. If neither the {bf:cweight} nor {bf:cprefix}  
options were specified then a "p_" prefix will be used.

{phang}
{opth noreport} suppress diagnostic report of variables created per context.{p_end}


{title:Examples:}

{pstd}The following command generates a battery of "m_" prefixed wt-weighted means from 
respondent-rated party positions and, based on those, a single "gov_" prefixed measure of  
government location. Before stacking the original party placements would have been held in 
a battery of variables such as lrp1-lrp10.{p_end}

{phang2}{cmd:. genplace plr [aw=wt] if govmembr==1, context(cid year) cprefix(gov_){p_end}{break}

{pstd}The following command generates a "gov_" prefixed measure of government locations based on 
expert-rated party placements (constant across respondents).{p-end}

{phang2}{cmd:. genplace xlr, context(cid year) cprefix(gov_) cweight(votepct)}{p_end}{break}


{title:Generated variables}

{pstd}
{cmd:genplace} saves the following variables or sets of variables:

{synoptset 16 tabbed}{...}
{synopt:m_{it:var [it:var] ...} (or other prefix set by option {bf:uprefix})}(perhaps 
weighted) means of variables generated for each variable in {it:varlist} as a first step (see NOTE 
2 above) item placements needed for a (second step) placement of the batteries containing those 
item placements. Such "m_" prefixed variables are only generated if no {it:cweight} option was 
specified.

{synopt:p_{it:var} (or the option cweight prefix or other prefix set by option {bf:cprefix})}
(perhaps weighted) means of battery items used to place (each) battery in terms of the concept 
that underlies it, as measured by its member items.{p_end}
