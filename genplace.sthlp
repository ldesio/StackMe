{smcl}
{cmd:help genplace}
{hline}

{title:Title}

{p2colset 7 19 22 0}{...}
{p2col :genplace {hline 2}} Generates a battery placement by averaging constituent item-level 
placements{p_end}
{p2colreset}{...}


{title:Syntax}

{p 6 13 0}
{opt genplace varlist [[weight]] [if]}
   [{cmd:,} {it:options}]

{synoptset 22 tabbed}{...}
{synopthdr}
{synoptline}
{synopt :{opt con:textvars(varlist)}}variables defining each context (e.g. country and year){p_end}
{synopt :{opt sta:ckid(varname)}}identifies different "stacks" (often battery items) across which 
mean placement(s) will be generated{p_end}
{synopt :{opt mpre:fix(name)}}prefix for names of any generated unit-level variables (default "m_"){p_end}
{synopt :{opt cwe:ight(varname)}}name of stack weight variable, constant across units{p_end}
{synopt :{opt cpr:efix(name)}}prefix for name of generated stack-level variable (default "p_"){p_end}
{synopt :{opt nor:eport}}suppress report of variables being generated{p_end}

{synoptline}

{title:Description}

{pstd}
The {cmd:genplace} command can be issued only after stacking. It places each battery named by a  
variable in {it:varlist} on the same scale as the placements, evauations or scores recorded for each 
item/stack in that battery. In voting studies, if the battery items are the left-right positions 
of political parties then the battery placement might be the left-right position of a legislature or 
government.{p_end}
{pstd}   NOTE (1): The battery-level placements being averaged by {cmd:genplace} must themselves be 
constant across units/respondents. Often they will derive from expert judgements or external documents 
(perhaps party manifestos). If the placements derive from unit-level variables (perhaps respondent 
judgements), and those have not already been averaged across units, then {cmd:genplace} 
can, in a first step, generate (weighted) means across units within battery items (perhaps pupils 
within classrooms) before generating battery (perhaps classroom) placements in a second step.{p_end}
{pstd}   NOTE (2): If battery placements derive from experts, manifestos, or some other external 
document, they will be constant across units, as already mentioned, but {cmd:genplace} takes those 
placement scores from the data, the same score for each unit/respondent within each battery/stack 
and context. This is the format used in many comparative datasets such as the ESS and CSES – a 
format that produces datasets containing much redundancy. (Users can, if they wish, reformat such 
datasets into level-specific components stored in separate files and input into different Stata 
dataframes, with linkage variables that save much filespace and execution time when using {cmd:genplace} 
and other utilities).{p_end}

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
that are members of that legislature). Use of the standard {help if:if} component of the {cmd:genplace} 
command line can focus the generic placement on certain members of the battery (perhaps government 
parties, thus producing a left-right government placement).{break}

{pstd}
SPECIAL NOTE ON WEIGHTING. The {help genplace:genplace} command places higher level objects in terms 
of the scale positions of lower level objects. Thus a political party might be placed in left-right 
terms by averaging the left-right placements it receives from respondents. When characterizing a 
higher-level object in terms of lower-level scores, those scores may need to be weighted. For example, 
survey respondents may need to be weighted according to their probabilities of being sampled. But if 
those parties in turn are averaged across a legislature so as to place that legislature in the 
same left-right terms, there is the opportunity to use quite different weights: perhaps 
votes received rather than respondents providing judgements. And if the party placements 
did not derive from respondents but from some external source (experts or manifestos or 
elites, perhaps) then respondent weights will be irrelevant. Thus, if survey responses are 
used to place a government in left-right terms then the appropriate weight might be the 
proportion of ministries received by each party comprising that government. This is why 
{cmd:genplace} uses two different weight variables: one named in the command line's [{help 
weight:weight}] component for weighting lowest level units and the other named in {cmd:genplace}'s 
{bf:cweight} option for weighting stack-level items.


{title:Options}

{phang}
{opth contextvars(varlist)} if present, variables whose combinations identify different electoral 
contexts (e.g. country and year) for each of which separate placements will be generated (same 
value for all units/respondents in each context). By default all units are assumed to belong to 
the same context.

{phang}
{opth stackid(varname)} if present, a variable identifying each different "stack" (equivalent to 
the {it:j} index in Stata's {bf:{help reshape:reshape long}} command) for which placements will be 
separately generated. The default is to use the "genplace_stack" variable. NOTE (3): there is no 
{cmd:nostack} option because placements apply to batteries that define each stack.

{phang}
{opth mprefix(name)} if present, prefix for the {it:varlist} names of generated placement variables 
(constant across units within contexts, if any): the (perhaps weighted) means of diverse unit-level 
placements produced in the first step of a two-step {cmd:gendist} (see NOTE 2 above). (Default is 
"m_").

{phang}
{opth cweight(varname)} if present, a weight (constant across units/respondents) used to place each 
item/stack according to the placements provided by experts or other sources in (or pertaining to) 
each context. The name of this variable will be used as a prefix for a generated battery placement 
variable if the {bf:cprefix} option is not specified. If neither the {bf:cweight} nor {bf:cprefix}  
options were specified then a "p_" prefix will be used.

{phang}
{opth cprefix(name)} if present, prefix for the name of the generated generic battery placement 
variable (constant across stacks and units within contexts, if any): the c-weighted mean of diverse 
battery-level placements. This prefix defaults to the "_"-suffixed name of the cweight variable, 
if specified, or to "p_" otherwise.

{phang}
{opth noreport} suppress diagnostic report of variables created per context.{p_end}


{title:Examples:}

{pstd}The following command, issued after stacking, generates a battery of "m_" prefixed 
wt-weighted means (constant across respondents) from respondent-rated party positions and, 
based on those, a single "gov_" prefixed measure of government location.{p_end}

{phang2}{cmd:. genplace plr [aw=wt] if govmembr==1, context(cid year) cprefix(gov_){p_end}{break}

{pstd}The following command, also issued after stacking, generates a "gov_" prefixed measure of 
government locations based on expert-rated party placements (constant across respondents).{p-end}

{phang2}{cmd:. genplace xlr, context(cid year) cprefix(gov_) cweight(votepct)}{p_end}{break}


{title:Generated variables}

{pstd}
{cmd:genplace} saves the following variables or sets of variables:

{synoptset 16 tabbed}{...}
{synopt:m_{it:var [it:var] ...} (or other prefix set by option {bf:uprefix})}(perhaps 
weighted) means of variables generated for each variable in {it:varlist} as a first step (see NOTE 
3 above) item placements needed for a (second step) placement of the batteries containing those 
item placements. Such "m_" prefixed variables are only generated if no {it:cweight} option was 
specified.

{synopt:p_{it:var} (or the option cweight prefix or other prefix set by option {bf:cprefix})}
(perhaps weighted) means of battery items used to place (each) battery in terms of the concept 
that underlies it, as measured by its member items.{p_end}
