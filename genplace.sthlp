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
{opt genplace} {varlist} 
   [{cmd:,} {it:options}]

{synoptset 22 tabbed}{...}
{synopthdr}
{synoptline}
{synopt :{opt con:textvars(varlist)}}variables defining each context (e.g. country-year){p_end} 
{synopt :{opt sta:ckid(varname)}}identifies different "stacks" for which mean placements will be 
separately generated{p_end}
{synopt :{opt pre:fix(name)}}prefix for names of generated variables (default is "p_"){p_end}
{synopt :{opt wei:ght(varname)}}unit (often respondent) weight (precludes {bf:cweight}){p_end}
{synopt :{opt cwe:ight(varname)}}stack weight, constant across units (precludes {bf:weight}){p_end}
{synopt :{opt nor:eport}suppress report of variables created per context{p_end}


{synoptline}

{title:Description}

{pstd}
{cmd:genplace} generates overall placements of items (e.g. political parties) separately for each 
context (if specified) by averaging the separate placements made by individual survey respondents, 
experts, or other sources pertaining to each context. Generated means can be weighted as in 
statistical analysis and/or by substantively defined weights, constant across respondents, specific  
to each item within context. NOTE (1): If placements have been made by experts, manifestos, or some 
other external source, they will be constant across units/respondents but {cmd:genplace} assumes 
that those placement scores are present in the data, the same score for each unit/respondent within
each (stack and) context. NOTE (2): Placements of external scores, already constant across units/
respondents, is a one-step process. Placements of unit-specific (perhaps respondent-judged) scores 
call for a two-step process in which the first step establishes the (perhaps weighted) mean 
placement across respondents and the second step proceeds as for externally-derived placements.

{pstd}
The {cmd:genplace} command can be issued before or after stacking. If issued before stacking the 
variable list will identify a battery of items each of which will be averaged into a (perhaps 
weighted) mean that is constant across the units/individuals at the lowest level of a multi-level 
data hierarchy, becoming synonimous with the external placements mentioned in the two NOTEs above. 
If issued after stacking it places each item/stack according to unit-level (previously stacked) 
evauations or scores. In either case the resulting (perhaps weighted) mean placement will be 
constant across units/respondents within items/stacks and within contexts.

{pstd}
SPECIAL NOTE COMPARING {help genplace:genplace} WITH {help genmeans:genmeans}: The data processing 
performed by {cmd:genplace} is computationally identical to that performed by {cmd:genmeans} but 
conceptually very different. The command {cmd:genmeans} generates means for numeric variables of any 
type and is limited to that one function. The command {cmd:genplace} generates placements for 
variables that are conceptually connected by being members of a battery of items, exactly as does 
{cmd:genmeans) but then proceeds to a second stage in which those means (or some other placement 
battery defined by option {bf:cweight} is used to average the item placements into a weighted mean 
placement relating to the battery as a whole (for example a legislature placed in left-right terms 
according to the individual placements of parties that are members of that parliament). Use of the
standard {bf:if} component of the {cmd:genplace} command line can limit the generic placement to 
certain parties (perhaps government parties, thus producing a left-right government location).
{break}

{title:Options}

{phang}
{opth contextvars(varlist)} if present, variables whose combinations identify different electoral 
contexts (e.g. country and year) for each of which separate placements will be generated (same 
value for all units/respondents in each context). By default all units are assumed to belong to 
the same context.

{phang}
{opth stackid(varname)} if present, a variable identifying each different "stack" (equivalent to 
the {it:j} index in Stata's {bf:{help reshape:reshape long}} command) for which placements will be 
separately generated. The default is to use the "genplace_stack" variable if the {cmd:gendist} 
command is issued after stacking. NOTE: there is no {cmd:nostack} option because placements apply 
to units that define each stack if the data are stacked.

{phang}
{opth prefix(name)} if present, prefix for generated placement variables which defaults to "m_" for 
means generated before stacking. After stacking the default prefix is the name of the cweight variable, 
if specified, or "p_" otherwise.

{phang}
{opth cweight(varname)} if present, a weight (constant across units/respondents) used to place each 
item/stack according to the placements provided by experts or other sources in (or pertaining to) 
each context. The name of this variable will be used as a prefix for generated variables if the 
{bf:prefix} option is not specified. Use of a {bf:cweight] requires stacked data.{p_end}

{phang}
{opth nor:eport} suppress diagnostic report of variables created per context.{p_end}


{title:Examples:}

{pstd}The following command, issued before stacking, generates p_-prefixed placements on a left-
right dimension, based on weighted party placements made by individual respondents and held in 
variables lrp1-lrp10.{p_end}

{phang2}{cmd:. genplace lrp1-lrp10, context(cid year) weight(wt)}{p_end}

{pstd}The following command, issued after stacking generates a measure of government location on 
a left-right dimension where party placements are based on votes cast for the party concerned and 
held in variables that are constant across respondents. NOTE: the weight would first need to be 
set to 0 for parties/stacks belonging to non-governing parties, otherwise the placement would be 
for the entire legislature.

{phang2}{cmd:. genplace plr, prefix(gov_) context(cid year) cweight(votepct)}{p_end}{break}

{title:Generated variables}

{pstd}
{cmd:genplace} saves the following variables or set of variables:

{synoptset 16 tabbed}{...}
{synopt:p_{it:var1} p_{it:var2} ... (or other prefix set by option {bf:prefix})} a set of variables 
placing objects in terms of the concept implied by the battery of variables named in {it:varlist). 
Generated for unstacked data.{p_end}{break}

{synopt:p_{it:vara} [p_{it:varb} ... (or other prefix set by option {bf:prefix})} a (set of different) 
variable(s) placing each stack in terms of the concept(s) named by each variable in {it:varlist}. 
Generated for stacked data.{p_end}{break}


NOTE: We should consider using the same syntax for weighting as used in statistical analyses; also 
subsetting by permitting an "if" suffix to the genplace command(would avoid the need for clumsy 
messing with cweights – see NOTE to 2nd example above). cweights would still be treated 
as options.
