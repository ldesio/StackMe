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


{synoptline}

{title:Description}

{pstd}
{cmd:genplace} generates overall placements of items (e.g. political parties) separately for each 
context (if specified) by averaging the separate placements made by individual survey respondents, 
experts, or other sources in or pertaining to each context. Generated means can be weighted as in 
statistical analysis or by substantively defined weights, constant across respondents, specific to 
each item within context.

{pstd}
The {cmd:genplace} command can be issued before or after stacking. If issued before stacking the 
variable list will name variables that, after stacking, will provide the values of a single 
variable (see {bf:{help genstacks:genstacks}}). If issued after stacking it places each stack 
according to unit-level (now stacked) evauations or scores, separately within each higher-level 
context. In either case the resulting mean will be constant across units/respondents within items/
stacks and within contexts.

{title:Options}

{phang}
{opth contextvars(varlist)} if present, variables whose combinations identify different electoral 
contexts (e.g. country and year) for each of which separate placements will be generated (same 
value for all units/respondents in each context). By default all units are assumed to belong to 
the same context.

{phang}
{opth prefix(name)} if present, prefix for generated placement variables (default is "p_").

{phang}
{opth stackid(varname)} if present, a variable identifying each different "stack" (equivalent to 
the {it:j} index in Stata's {bf:{help reshape:reshape long}} command) for which placements will be 
separately generated. The default is to use the "genplace_stack" variable if the {cmd:gendist} 
command is issued after stacking. NOTE: there is no {cmd:nostack} option because placements apply 
to units that define each stack if the data are stacked.

{phang}
{opth weight(varname)} if present, provides the same weight as used in analysis commands to be 
applied when averaging the placements made by indiviual respondents.

{phang}
{opth cweight(varname)} if present, a weight (constant across units/respondents) used to place each 
item/stack according to the placements provided by experts or other sources in (or pertaining to) 
each context.{p_end}


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
