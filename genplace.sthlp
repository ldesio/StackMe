{smcl}
{cmd:help genplace}
{hline}

{title:Title}

{p2colset 5 20 22 2}{...}
{p2col :genplace {hline 2}}Generates placements for each stack in terms of a stack-level position derived 
from respondent judgements or other measures{p_end}
{p2colreset}{...}


{title:Syntax}

{p 8 16 0}
{opt genplace} {varlist} 
   [{cmd:,} {it:options}]

{synoptset 25 tabbed}{...}
{synopthdr}
{synoptline}
{synopt :{opth con:textvars(varlist)}}if present, a set of variables identifying different electoral contexts 
(by default all cases are treated as part of the same context).{p_end}
{synopt :{opth sta:ckid(varname)}}a variable identifying different "stacks", for which means will be 
separately generated if {cmd:genplace} is invoked after stacking.{p_end}
{synopt :{opt pre:fix(name)}}prefix for varname of a variable holding mean-plugged placement variables 
(default is "p_"){p_end}
{synopt :{opt wei:ght(varname)}}if present, variable holding the respondent weight to be applied in each 
context (precludes {bf:cweight}){p_end}
{synopt :{opt cwe:ight(varname)}}if present, variable holding the stack weight (constant across respondents – 
precludes {bf:weight}) {p_end}


{synoptline}

{title:Description}

{pstd}
{cmd:genplace} generates overall placements of items (e.g. political parties) separately for different contexts 
(if specified) based on averaging the separate placements made by individual survey respondents, experts or other 
sources in, or pertaining to, that context. Provision is made for weighting these means either with the same 
weighting variable used in analysis of the same respondents or with a variable, constant across respondents, 
establishing the weight to be given to that stack in that context.

{pstd}
The {cmd:genplace} command can be issued before or after stacking. If issued after stacking, it places each stack 
according to evauations or scores, separately within each higher-level context. If issued before 
stacking the variable list will name variables that, after stacking will provide the values of a single variable 
(the stub from the variables enumerated in {it:varlist}) defining the placement of different stacks in terms of 
that variable, separatelhy within each higher-level context.

{title:Options}

{phang}
{opth contextvars(varlist)} if present, variables whose combinations identify different electoral contexts 
(e.g. country and year). By default all cases are assumed to belong to the same context.

{phang}
{opth stackid(varname)} if specified, a variable identifying each different "stack" (equivalent to the Stata 
{bf:{help reshape:reshape long}}'s {it:j} index) for which placements will be separately generated. The default 
is to use the "genplace_stack" variable if the {cmd:gendist} command is issued after stacking.

{phang}
{opth prefix(name)} if present, provides a prefix for generated placement variables (default is "p_").

{phang}
{opth weight(varname)} if present, provides the same weight as used in analysis commands to be applied when 
averaging the placements made by indiviual respondents.

{phang}
{opth cweight(varname)} if present, provides a weight, constant across respondents, used to place each stack 
in terms of the placements provided by experts or other sources in or pertaining to each context.{p_end}

{title:Examples:}

{pstd}The following command generates placements on a left-right dimension before stacking, based on weighted 
responses where party placements were made by individual respondents and held in variables lrp1-lrp10

{phang2}{cmd:. genplace lrp1-lrp10, context(cid year) weight(wt){p_end}

{pstd}The following command generates placements on a left-right dimension after stacking, where party 
placements are based on votes cast for the party concerned and held in variables that are constant across 
respondents

{phang2}{cmd:. genplace plr, context(cid year) cweight(votepct){p_end}

{title:Generated variables}

{pstd}
{cmd:genplace} saves the following variables or set of variables:

{synoptset 16 tabbed}{...}
{synopt:p_{it:var1} p_{it:var2} ... (or other prefix set by option {bf:prefix})} a set of variables placing 
objects in terms of the concept implied by the battery of variables named in {it:varlist) (before stacking).

{synopt:p_{it:vara} [p_{it:varb} ... (or other prefix set by option {bf:prefix})} a (set of different) 
variable(s) placing each stack in terms of the concept(s) named by each variable in {it:varlist} (after 
stacking).
