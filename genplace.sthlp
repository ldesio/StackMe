{smcl}
{cmd:help genplace}
{hline}

{title:Title}

{p2colset 7 19 19 0}{...}
{p2col :genplace {hline 2}}Generates customizable stack or battery placements (e.g. averages) of  
lower-level scores for variables constituting each named stack/battery (also providing an interface for 
user-written programs){p_end}
{p2colreset}{...}


{title:Syntax}

{p 4 13 11}
{opt genplace varlist [if][in][weight], options}

	or

{p 4 13 11}
{opt genplace varlist [if][in][weight], options || varlist || ...}


{p 4}The second syntax permits the same options to be applied to multiple varlists.



{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{p2colset 5 26 28 2}
{synopt :{opt con:textvars(varlist)}}variables defining each context (e.g. country and year){p_end}
{synopt :{opt noc:ontexts}}disregard context distinctions (stack distinctions cannot be disregarded){p_end}
{synopt :{opt sta:ckid(varname)}}(required) identifies different "stacks" (often battery items) across 
which mean placement(s) will be generated{p_end}
{synopt :{opt two:step}}generate mprefixed-placements, constant across battery items, from unit-level data as 
a basis for battery-level placements ({cmd:genplace} requires placements to be constent across across battery 
items){p_end}
{synopt :{opt mpr:efix(name)}}prefix for name the of stack-level placement variable(s) (default "m_"), 
optionally generated in the first step of a two-step battery placement{p_end}
{synopt :{opt ppre:fix(name)}}prefix for name(s) of generated battery-level placement variable(s) 
(defaults to "p_"){p_end}
{synopt :{opt cwe:ight(varname)}}name of (optional) stack-level weight variable{p_end}
{synopt :{opt lim:itdiag(#)}}number of contexts for which to report on variables being generated 
(default is to report progress for all contexts){p_end}
{synopt :{opt nod:iag}}equivalent to {opt lim:itdiag(0)}, suppressing progress reports{p_end}
{synopt :{opt cal:l(command exp)}}invoke a Stata command defining the placement 
to be performed, if not the default placement according to mean value. For example 
"call( egen m_* = mean(*) )", where "*" stands-in for the variables listed in {varlist}, 
would initiate the generation of battery items using the method that is the default for {cmd:genplace}{p_end}
{synopt :{opt cal:l(program local-list)}}invoke a user-written program by specifying its name and a list 
of {cmd:genplace} or user-supplied locals that you want your program to be able to access. See help 
{help genWriteYourOwn} for details and the example of a model program (that calculates polarization 
measures for a battery of parties).{p_end}
{synopt :{opt cal:l(iyield iyprefix isupport icred)}}invoke another model for a user-written program – 
this one calculates and saves  yield in votes gained by party emphasis on each of a number of issues. 
Battery items are here assumed to be measures of support for political parties; IY indices are 
calculated for each party, optionally weighted by the respondent-evaluated credibility of each party 
regarding the issue concerned. See help {help genWriteYourOwn} for details.{p_end}

{synoptline}

{title:Description}

{pstd}
Because it operates on the variables that were stubnames before stacking (see {help genstacks}), the 
{cmd:genplace} command can be issued only after stacking. It places each battery named by a  
variable in {varlist} on the same scale as the placements, evauations or scores recorded for each 
item/stack in that battery. In voting studies, if the battery items are the left-right positions 
of political parties then the battery placement might be the left-right position of a legislature or 
government.{p_end}
{pstd}{space 3}{cmd:genplace} by default places batteries at the mean of positions occupied by members 
of those batteries, as just mentioned. However {cmd:genplace} also provides a scaffolding upon which users 
can "hang" special-purpose programs that place batteries in terms of other concepts than the mean (perhaps 
party polarization), or can place stack-level components of those batteries in terms of stack-level concepts 
(perhaps the yield in terms of votes that parties receive from the stances they take on specific issues). 
These two examples already exist as callable programs (see the two {opt call} options).{p_end}
{pstd}{space 3}NOTE (1): The battery-level placements being processed by {cmd:genplace} must themselves be 
constant across observations/respondents. Often they will derive from expert judgements or external documents 
(perhaps party manifestos). If the placements derive from unit-level variables (perhaps respondent 
judgements (see {cmd:help stackme}'s {help stackme##Vocabulary:vocabulary} discussion), and those have not 
already been averaged across battery items, then {cmd:genplace} 
can, in a first step, generate (weighted) means across observations within batteries (perhaps pupils 
within classrooms) before generating battery (perhaps classroom) placements in a second step.{p_end}
{pstd}{space 3}NOTE (2): If battery placements derive from experts, manifestos, or some other external 
document, they will be constant across battery items, as already mentioned, but {cmd:genplace} takes those 
placement scores from the data, the same score for each unit/respondent within each battery/stack 
and context. This is the format used in many comparative datasets such as the ESS and CSES – a 
format that produces datasets containing much redundancy. (Users can, if they wish, reformat such 
datasets into unit-specific components stored in separate files and input into different Stata 
dataframes, with linkage variables that save much filespace (and perhaps also execution time) when 
using {cmd:genplace} and other utilities).{p_end}
{pstd}{space 3}NOTE (3): If multiple ||-delimeted batteries are listed in the {cmd:genplace} 
{it:varlists} then all of these batteries will be treated in the same fashion, as established by the options 
accompanying that command. 
So the user might place a government in terms of its position regarding each of a number of policies. 
This means that the battery-names listed in {it:varlist} must be batteries of items that pertain to 
the same object. Only the user can verify that this is the case.

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
that are members of that legislature). Use of the standard [{help if:if}] component of the {cmd:genplace} 
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
seats controlled rather than respondents providing judgements. And if the party placements 
did not derive from respondents but from some external source (experts or manifestos or election 
outcomes, perhaps) then respondent weights will be irrelevant. Thus, if survey responses are 
used to place a government in left-right terms then the appropriate weight might be the 
proportion of ministries received by each party comprising that government. This is why 
{cmd:genplace} uses two different weight variables: one named in the command line's [{help weight}] 
expression for weighting lowest level units and the other named in {cmd:genplace}'s {bf:cweight} 
option for weighting context-level items.


{title:Options}

{phang}
{opth contextvars(varlist)} if present, variables whose combinations identify different electoral 
contexts (e.g. country and year) for each of which separate placements will be generated (same 
value for all units/respondents in each context). By default all units are assumed to belong to 
the same context.

{phang}
{opt nocontexts} if present, disregard distinctions between contexts (stack distinctions cannot be 
disregarded since these are the objects being placed by this command).

{phang}
{opth stackid(varname)} (required) a variable identifying each different "stack" (equivalent to 
the {it:j} index in Stata's {bf:{help reshape:reshape long}} command) for which placements will be 
separately generated. The default is to use the "SMstkid" variable. NOTE: there is no 
{cmd:nostack} option because placements relate to batteries that define each stack.

{phang}
{opt twostep} if present, generate the mean placement of each stack from unit-level data before generating 
battery-level placements (the extra step may be needed to produce placements that are constant across units).

{phang}
{opth mprefix(name)} if present, prefix for the name of the stack mean, generated in the (optional) 
first step of a two-step {cmd:genplace} command and constant across units within stacks: the optionally 
c-weighted mean of diverse battery-level placements. This prefix defaults to the "_"-suffixed 
name of the cweight variable, if specified, or to "m_" otherwise.

{phang}
{opth pprefix(name)} if present, prefix for the {it:varlist} names of generated battery-level placement 
variables (constant across units within contexts). Default is "p_".

{phang}
{opth cweight(varname)} if present, a weight (variable across battery items) used to place each 
item/stack according to the placements provided by experts or other sources in (or pertaining to) 
each context. The name of this variable will be used as a prefix for a generated battery placement 
variable if the {bf:mprefix} option is not specified. If neither the {bf:cweight} nor {bf:mprefix}  
options were specified then an "c_" prefix will be used.

{phang}
{opth limitdiag(#)} only display diagnostic report for the first # contexts (by default report 
variables created for all contexts).{p_end}

{phang}
{opt nodiag} equivalent to {opth limitdiag(0)}.{p_end}

{phang}
{opth call(command exp)} invoke a Stata command defining the nature of the placement 
to be performed, if not the default. For example "call( egen m_* = mean(*) )", where "*" stands-in 
for the variables listed in {varlist}, would invoke the generation of battery items calculated 
in the manner that would occur by default for {cmd:genplace} (and thus produces the same results 
as would have been generated by default). {bf:NOTE} that {cmd:genplace} executes this command separately 
for each context defined by {opt con:textvars} and {opt sta:ck}, whether or not the command 
concerned is "by"-able. So {cmd:genplace} can execute commands context by context 
even if Stata could not do so.{p_end}

{phang}
{opth call(program local-list)} invoke a user-written program by specifying, in the first argument, 
the name of the program and, in subsequent arguments, the contents of {cmd:genplace} local macros 
named by those arguments or, if empty, the local names themselves for use by the program. See help 
{help genWriteYourOwn} for details and a model program (that calculates polarization measures 
for a battery of parties).{p_end}

{phang}
{opth call(iyield iyprefix isupport icred)} invoke another model for a user-written program – this 
one calculates and saves measures of the yield in votes gained by party emphasis on each of a number 
of issues. It saves the resulting index in {varname}s constructed by prepending (with iy_ or such 
other prefix as provided in the second argument) the stubnames of battery items (assumed to be 
measures of support for political parties, for which context-level means have been generated in 
a {cmd:genplace} first step calculation). The third and fourth arguments contain stubnames for 
lists of variables measuring support for specific issues among supporters of each party and, 
optionally, the credibility respondents see for each party regarding each issue. Issue yield index 
values are generated in the same "wide" format as the issue variables from which those yields are 
generated. They can be summarized in various ways for ensuing analyses or stacked so that issues 
become nested within parties within respondents. See help {help genWriteYourOwn} for details.{p_end}


{title:Examples:}

{pstd}The following command, issued after stacking, generates a battery of "m_" prefixed 
wt-weighted means (rendered constant across respondents by use of the {opt plu:gall} option) 
from respondent-rated party positions and, based on those, a single "legis_" prefixed 
measure of the legislature's left-right location in particular countries and years:{p_end}

{phang2}{cmd:. genplace plr [aw=wt], plugall context(cid year) stackid(stkid) cprefix(legis_)}{p_end}{break}

{pstd}The following command, also issued after stacking, generates a "gov_" prefixed measure of 
vote-weighted government locations based on expert-rated party placements (necessarily constant 
across respondents even without using the {opt plu:gall} option):{p_end}

{phang2}{cmd:. genplace xlr if govmembr==1, context(cid year) stackid(stkid) cprefix(gov_) cweight(votepct)}{p_end}{break}

{pstd}The following example, again issued after stacking, uses {cmd:genplace}'s {opt call} option to invoke 
an ostensibly user-written program that calculates Issue Yield Indices (De Sio and Weber 2014), building 
on the stack-level means generated in the first step of a two-step {cmd genplace} command: 

{phang2}{cmd:. genplace vote, context (cid year) stackid(stkid) call(iyield iy_ issusupport issucred)}


{title:Generated variables}

{pstd}
{cmd:genplace} may save the following variables or sets of variables:

{synoptset 16 tabbed}{...}
{synopt:m_{it:var} m{it:var} ...} (or other prefix set by option {bf:mprefix}) (perhaps 
weighted) means of variables generated for each variable in {it:varlist} as a first step (see NOTE 
3 above) needed for a (second step) placement of the batteries containing those 
item placements. Such "m_" prefixed variables are only generated if no {it:cweight} option was 
specified.

{synopt:p_{it:var} p_{it:var} ...} (or other prefix set by option {opt pwe:ight}) (perhaps weighted) 
means of battery items used to place (each) battery in terms of the concept that underlies it, as 
measured by its member items.{p_end}

{synopt:c_{it:var} c_{it:var} ...} (or other prefix set by option {opt cwe:ight}}) a weight 
at the battery level (constant across units) to be used when placing the battery itself.

{pstd}Such other variables as may be created by user-written programs, perhaps with variable prefixes 
established by the user program interface (see option {opt cal:l(iyield)} for an example).{p_end}


{title:Reference}

{pstd}
To understand the function of {opt call(iyield...)}, whose utility will likely not extend beyond the 
subfield of electoral studies) see:{break}
De Sio, L., and Weber, T. (2014). "Issue Yield: A Model of Party Strategy in Multidimensional Space." 
{it:American Political Science Review}, 108(4): 870-885.

