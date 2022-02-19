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
{opt genplace varlist [weight] [if]}
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
{synopt :{opt nor:eport}suppress report of variables created per context{p_end}


{synoptline}

{title:Description}

{pstd}
The {cmd:genplace} command can be issued only after stacking. It places each item/stack according 
to unit-level (previously stacked) placements, evauations or scores. Command {cmd:genplace} generates 
an overall (mean) placement of a battery of items (e.g. political parties separately for each context 
(if specified) by averaging the separate placements of each battery item into (perhaps weighted) 
means of the placements originally produced by individual survey respondents, experts, or other 
external sources pertaining to each context. Generated means can be weighted in standard  
Stata fashion and/or by substantively defined weights, constant across respondents, specific to 
each item within stack. NOTE (1): If placements derive from experts, manifestos, or some other 
external document, they will be constant across units/respondents but {cmd:genplace} takes those 
placement scores from the data, the same score for each unit/respondent within each battery/stack 
and context. NOTE (2): If placements derive from the units/respondents (potentially different for 
each unit) then {cmd:genplace} first computes (perhaps weighted) mean placements across units/
respondents before using those to derive the weighted battery placement.

{pstd}
Resulting (perhaps weighted) 
mean placement of the battery will be constant across the battery's items/stacks as well as 
across the units/respondents in each stack within contexts. If placements are to be based on 
unit/respondent evaluations specific to each unstacked unit, those placements need to have been 
averaged (perhaps using command {cmd:genmeans} before the data were stacked. Users with large 
datasets should consider use of {help frame:frame} linkages to reduce computational, memory and 
filespace demands.

{pstd}
SPECIAL NOTE COMPARING {help genplace:genplace} WITH {help genmeans:genmeans}: The data processing 
performed by the first stage of a two-stage {cmd:genplace} command (see NOTE 2 above) is 
computationally identical to that performed by command {cmd:genmeans} but conceptually very 
different. The command {cmd:genmeans} generates means for numeric variables without regard to any 
conceptual grouping of variables inherent in batteries that might contain (some of) those variables. 
It is also limited to that one function. The command {cmd:genplace} can do the same for variables 
that are conceptually connected by being members of a battery of items but then proceeds to a second 
stage in which those means (or some other placement battery defined by option {bf:cweight} are used 
to average the item placements into a weighted mean placement regarding the battery as a whole (for 
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
separately generated. The default is to use the "genplace_stack" variable if the {cmd:gendist} 
command is issued after stacking. NOTE: there is no {cmd:nostack} option because placements apply 
to units that define each stack if the data are stacked.

{phang}
{opth uprefix(name)} if present, prefix for the {it:varlist} names of generated placement variables 
(constant across units within contexts, if any): the (perhaps weighted) means of diverse unit-level 
placements (defaults to "m_").

{phang}
{opth cprefix(name)} if present, prefix for the name of the generated generic battery placement 
variable (constant across stacks and units within contexts, if any): the c-weighted mean of diverse 
battery-level placements. This prefix defaults to the "_"-suffixed name of the cweight variable, 
if specified, or "p_" otherwise.

{phang}
{opth cweight(varname)} if present, a weight (constant across units/respondents) used to place each 
item/stack according to the placements provided by experts or other sources in (or pertaining to) 
each context. The name of this variable will be used as a prefix for generated variables if the 
{bf:cprefix} option is not specified (the uprefix will be used if the battery is being placed 
according to unit/respondent placements).

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
{synopt:m_{it:var1 [it:var2] ...} (or other prefix set by option {bf:uprefix})} as the stubnames  
of the batter(ies) of variable(s) named in {it:varlist). 

{synopt:p_{it:var} (or the option cweight prefix or other prefix set by option {bf:cprefix})} as 
the overall generic name(s) of batter(ies) placed by (set of different) 
variable(s) placing each stack in terms of the concept(s) named by each variable in {it:varlist}. 
Generated for stacked data.{p_end}{break}


NOTE: I am not sure whether I am accurately describing the procedure actually coded for naming the 
cprefix if not user-supplied. Either the dofile code or this help file may need adjustment accordingly.
