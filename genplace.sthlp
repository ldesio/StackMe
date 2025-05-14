{smcl}
{cmd:help genplace}
{hline}

{title:Title}

{p2colset 4 16 16 2}{...}
{p2col :{ul:genpl}ace {hline 2}}Generates customizable battery placements (e.g. averages) of lower-level 
scores for variables constituting each named stack or other indicator (also providing an interface for 
utility and user-written programs). See {help genplace##Placements:What are placements?}, below.{p_end}
{p2colreset}{...}


{title:Syntax}

{p 4 13 2}
{cmdab:genpl:ace} {varlist} {ifin} {weight}, options

	or

{p 4 13 11}
{cmdab:genpl:ace} [{help genplace##indicatorvars:{it:prefixvars}} : ] {varlist} {weight} ||   ...{break}
[{help genplace##indicatorvars:{it:prefixvars}} : ] {varlist} {weight} ||   ...{break}
[{help genplace##indicatorvars:{it:prefixvars}} : ] {varlist} {weight} , options

{p 4 4 2}All Varlists should consists of stacked variables (variables with the character string "stkd_" at the 
start of their variable labels); or should have been merged from external data measured at that level (for 
example external party data to match stacked party variables). Unit-level variables that were not members 
of any battery cannot be placed. {bf:Speed of execution can be much increased} by grouping together, on one 
command-line, varlists that employ the same options; "{ifin}" must follow the first varlist; ", options" must 
follow the last varlist; {weight} expressions can follow any varlist.

{p 4 4 2}Names of resulting placement measures are constructed either by prefixing (by "pp_" or other 
string set by option {opt ppr:efix}) the name of the stack being placed or by prefixing (by "pi_" or other 
string set by option {opt ipr:efix}) the name of the indicator being placed (but, when placements are 
weighted, using an optional list of {help genplace##cweight:cweight}s, the resulting outcome varname will 
instead be prefixed by the name of the relevant {help genplace##cweight:cweight} variable). See the 
{cmd:stackMe} helpfile's {help stackme##syntax:Syntax} section for an elaboration of the second syntax 
that permits outcome variables to be provided with distinguishing prefixes.

{p 4}aweights, fweights, and iweights are allowed.{p_end}


{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}

{p 2}{ul:Placement options}{p_end}
{p2colset 5 24 19 2}
{synopt :{opt ind:icator(varname [ if exp ] )}}name(s) of (optional) 0,1 indicator variable identifying 
the stacks that will contribute to placing the object(s) named by the indicator(s). Optionally, the keyword 
'{bf:if}' followed by a logical expression leads to a new variable being generated as the indicator, 
coded 1 if the expression is true or zero otherwise. NOTE that any indicator variable established 
in one of these ways will be overridden by a corresponding {help genplace##indicatorvars:indicatorvars} list 
used to prefix the command-line {varlist}. If no indicator is provided in one of these ways then, by default, 
it is the {varlist} stacks themselves that are placed according to mean stack values. An indicator varlist is 
not permitted if a cweight varlist is provided.{p_end}
{...}{p2colset 5 22 19 2}
{synopt :{opt cwe:ight(varlist)}}name(s) of (optional) stack-level weight variable(s) – required for single step 
placements. NOTE that any (list of) weight variable(s) established by use of this option is overridden by a 
corresponding {help genplace##cweight:cweight}-list used to prefix the {cmdab:genpl:ace} command-line {varlist}.
A cweight varlist is not permitted if an indicator varlist is provided.{p_end}
{...}{p2colset 5 21 19 2}
{synopt :{opt wtp:refixvars}}optionally interpret any prefixvars (preceeding the {cmd:genplace} {varlist}) as 
naming a (set of) cweight variable(s) instead of naming a (set of) indicator variable(s) – the default.{p_end}
{synopt :{opt stk:level}}optionally ensure that the working data passed to the command for processing is organized 
at the stack level of aggregation rather than at the (default) context level.{p_end}
{synopt :{opt two:step}}generate pm_prefixed-means, generally constant across battery items, from 
unit-level data as a basis for battery-level placements (by default {cmdab:genpl:ace} assumes placements 
to be constent across battery items).{p_end}
{synopt :{opt noplu:g}}disregard the expectation that battery-level placements will be made on the 
basis of mean values that have been rendered constant across respondents.{p_end}
{synopt :{opt cal:l(SMsubprogram [, options])}}invoke a user-written subprogram by specifying its name 
followed by optional components of a standard Stata command-line. See under {help genplace##Options:Options}, 
below, for further details.{p_end}

{p 2}{ul:Data-structure options}{p_end}

{...}{p2colset 5 26 19 2}
{synopt :{opt con:textvars(varlist)}}(generally unspecified) list of variable(s) that define the context 
(often country and year) within which outcomes will be separately measured (required if the default 
recorded as a 'data characteristic' by command {cmdab:SMset:contexts} is to be overriden).{p_end}
{...}{p2colset 5 21 19 2}
{synopt :{opt nocon:texts}}disregard context distinctions (stack distinctions, defined by the {cmd stackme} 
special variable {it:{cmd:SMstkid}}, cannot be disregarded by {cmdab:genpl:ace}).{p_end}
{...}{p2colset 5 21 19 2}

{p 2}{ul:Output and naming options}{p_end}

{synopt :{opt mpr:efix(string)} THIS OPTION DOES NOT EXIT for genplace, since pm_-prefixes are only used 
for first-step variables needed in an optioned twostep {cmdab:genpl:ace} procedure.{p_end}
{synopt :{opt ppr:efix(string)}}optional string used to replace the default (pp_) string prefix for {varlist} 
(input) names when those prefixed names are used for generated outcome variables holding the estimated (mean) 
placements of those inputs (default name should not be changed if var might be used in further genplaoce commands).{p_end}
{synopt :{opt ipr:efix(string)}}optional string used to replace the default (pi_) string prefix for indicator 
(see first option above) names when those prefixed names are used for generated outcome variables holding the 
estimated (mean) placements of those indicators.{p_end}

{p 2}{ul:Diagnostic options}{p_end}

{synopt :{opt lim:itdiag(#)}}number of contexts for which to report progress and diagnostics regarding 
variables being generated (default is to report progress for all contexts).{p_end}
{synopt :{opt nod:iag}}equivalent to {opt lim:itdiag(0)}, suppressing all diagnostic output.{p_end}

{synoptline}

{marker Placements}
{title: What are placements?}

{pstd}
A player may "place" a ball on the ground before kicking it and, depending on where the ball was "placed", may 
have a better of worse chance of making a conversion or scoring a goal. So "place" can be an action or a location. 
Command {cmdab:genpl:ace} gets its name from both aspects of the word's meaning: it (actively) "places" batteries 
of survey items while it also serves as a repository where other (often user-written) programs are (passively) 
"placed" for structural reasons and/or as a matter of convenience.


{marker Description}
{title: Description}

{pstd}
Because it spatially "place"s variables that were stubnames before stacking (see {help genstacks:{ul:genst}acks}), 
or yet higher-level indicators (binary variables), the {cmdab:genpl:ace} command can be issued only after stacking. 
Nevertheless, this is the single {cmd:stackMe} command that, when handling stacked data, does not by default call 
for data organized at the stack level of aggregation. Because it places stacks in terms of their lower-level 
characteristics, {cmdab:genpl:ace} requires access to the data at the contextual level, where it can determine the 
characteristics of individual stacks. Many user-written programs will, however, call for data organized at the level 
of the individual stack as is customary and, to that end, {cmdab:genpl:ace} provides the option {opt stk:level} to 
meet that need. Indeed the {cmdab:genpl:ace} command might be referred to as the "Swiss army knife" of {cmd:stackMe} 
commands. Because it serves as the repository for all procedures not specifically provided by {cmd:stackMe}'s other 
'{cmd:gen...}' commands, {cmdab:genpl:ace} is by far the most intricate of all {cmd:stack:me} commands.{p_end}
{pstd}{space 3}Just as {help genyhats:{ul:genyh}ats} has two different modes of operation, distinguished by the 
use made of a prefix variable, so {cmdab:genpl:ace} also has two modes of operation distinguished in analageous 
manner: placement of batteries according to the means of constituent (lower level) variables and placement of 
higher-level indicators according to the means of constituent battery-level variables (stacked variables). The 
level of aggregation of means used for placements is established by the level of aggregation of the variable(s) 
in the {cmdab:genpl:ace} command-line {varlist} (all of which must be measured at the same level). The level of 
aggregation of the variable being placed is also subject to user option, defined by whether an indicator variable 
was optioned and, if so, the level of aggregation of that indicator variable, as illustrated in the Figure that 
follows. 
{asis}
 					
          .----------- >  Outcome indicator at level 3 (e.g. Left-right stance of legislature)
          |                                       ^
          | pi-prefix                             | pi-prefix
          |                                       |
          |                                       |
          |                                       '
          |    ,---- >  Outcome variable or indicator at level 2 (e.g. Party left-right stance)
          |    |                                  ^
          |    | pp-prefix if placing level-2     | pm-prefix if generating level-2 means 
          |    | battery var(s); pi-prefix if     | (summarizing level-1 assessments)  to
          |    | placing a level-2  indicator     | use in placing  a  level-3  indicator
          |    |                                  | 
          '    '                                  '
        Input variable at level 2 (e.g. Stacked assessments of party left-right stances)


{smcl}
{pstd}
As illustrated in the above diagram, each input variable to a {cmdab:genplace} procedure should be a level-2 
battery/stack that was generated by a previous {cmdab:genst:acks} command or {help merged} from some external 
source such as an expert survey or party manifesto/platform; or it can be a level 2 "pm_"-prefixed variable 
generated during {cmdab:genpl:ace}'s (optional) first step. Turning to outcomes, these can be level 2 
"pp_"-prefixed placements of batteries whose individual stacks were battery members before stacking; or they 
can be "pi_"-prefixed placements of indicator variables at the same level; or they can be higher-level 
"pi_"-prefixed placements of an indicator variable whose values only vary as between higher-level objects 
(see below). The segment of a data matrix depicted below illustrates how outcome and indicator variables are 
related to each other and to stacked battery items.{p_end}
{asis}

       -----------------------------------------------------------
        SMunit  SMstkid  SMitem  ptlrpos  pm_lr   govpty  pi_gov  (source of pi_gov)
	   -----------------------------------------------------------
          1        1      lab      1.9     2.5      1      3.25      =(2.5+4.0)/2
          1        2      con      7.8     8.2      0      0.00      =0
          1        3      lib      4.5     4.0      1      3.25      =(2.5+4.0)/2
          2        1      lab      3.1     2.5      1      3.25      =(2.5+4.0)/2
          2        2      con      8.2     8.2      0      0.00      =0
          2        3      lib      3.5     4.0      1      3.25      =(2.5+4.0)/2
          3        1      lab      2.5     2.5      1      3.25      =(2.5+4.0)/2
          3        2      con      8.5     8.2      0      0.00      =0
          3        3      lib      4.0     4.0      1      3.25      =(2.5+4.0)/2
       -----------------------------------------------------------

{smcl}
{pstd}
The first two columns tell us we have three respondents each of whom provided information about three 
parties. The third column shows values of a string variable that provides the common abbreviation for each of 
three British parties (in practice it would be more common for these names to be spelt out in full in labels that 
were associated with three numeric values). The 'ptlrpos' column contains seemingly reasonable positions on a 
ten-point left-right scale that might have been provided for each of the three parties by each of the three 
respondents. The 'pm_lr' column appears to contain the left-right positions of the three parties (averaged across 
respondents as though the respondents were being treated as experts regarding party positions, with their 
different judgements being averaged across respondents). Moving on, we find a column of 0 and 1 codes that 
is labeled 'govpty'. The codes evidently indicate, for each party, whether it is a member of the government 
(=1) or not (=0). Those codes serve as a sort of sieve, determining whether 'ptlrpo' is allowed to pass through 
to the final column, 'pi_gov'. We can see that, wherevar the sieve is blocked by a 0 code, 'pi_gov' is also 
zero. Only where 'govpty' is coded 1 does 'pi_gov' get a value based on the ('pm_lr') means of the parties that 
are indicated by 1's. The logic is straightforward if not entirely obvious.{p_end}

{pstd}To add to this complexity, an indicator variable might already be present in a dataset containing variables 
whose means will provide that variable's placements (for example if that indicator had been obtained from an 
archive or other external source); or the indicator's values might be defined by the user, using the optional 
'if' syntax found in {cmdab:genpl:ace}'s {help genplace##Options:{ul:ind}icator} option.{break}

{pstd}
While, faced with a unit-level {varlist}, {cmdab:genpl:ace} by default places batteries at the mean of positions 
indicated by respondents at that level, it expects those positions to have been made constant across respondents, 
as was done for the dataset segment shown above, just as though the positions had been obtained from an expert 
survey or party manifesto/platform. Such "unit-invariant" responses might also have been obtained from 
{cmd:stackMe}'s {cmdab:genme:ans} or {cmdab:gendi:st} commands (provided {opt noplu:g} was NOT optioned in the 
former case and {opt plu:gall} WAS optioned in the latter case). But such unit-invariant means might also be 
obtained from the first step of a two-step {cmdab:genpl:ace} procedure (optioned by the {opt two:step} option), 
so long as {opt noplu:g} was not also optioned).{p_end}

{pstd}But wait: there's more! {cmdab:genpl:ace} can be used not only to place the locations of higher-level 
variables in terms of the mean values of lower-level variables but also as an interface to user-written 
subprograms that can place batteries in terms of statistical measures other than the mean (perhaps party 
polarization), or can place stack-level components of those batteries in terms of stack-level concepts 
(perhaps the yield in terms of votes that parties receive from the stances they take on specific issues). 
These two examples already exist as callable programs (see the two {opt call} options) below.{p_end}
{pstd}{space 3}NOTE (1): The battery-level placements being processed by {cmd:genplace} should generally 
themselves be constant across observations/respondents. Often they will derive from expert judgements or 
external documents (perhaps party manifestos/platforms). If the placements derive from unit-level variables 
(perhap respondent assessments – see {cmd:help stackme}'s {help stackme##Vocabulary:vocabulary} discussion), 
and those have not already been averaged across battery items, then {cmd:genplace} can, in a first step, 
generate (weighted) means across observations within batteries (perhaps pupils within classrooms) before 
generating battery (perhaps classroom) placements in a second step.{p_end}
{pstd}{space 3}NOTE (2): If battery placements derive from experts, manifestos, or some other external 
source, they will be constant across battery items, as already mentioned, but {cmd:genplace} takes 
those placement scores from the data, the same score for each unit/respondent within each battery/stack 
and context. This is the format used in many comparative datasets such as the ESS and CSES – a format 
that produces datasets containing much redundancy. (Users can, if they wish, reformat such datasets 
into unit-specific components stored in separate files and input into different Stata dataframes, with 
linkage variables that save much filespace (and perhaps also execution time) when using {cmd:genplace} 
and other utilities).{p_end}
{pstd}{space 3}NOTE (3): If multiple ||-delimeted batteries are listed in a {cmdab:genpl:ace} command-line 
then all of these batteries will be treated in the same fashion, as established by options accompanying 
that command, except that each input {varlist} can be prefixed by a list of {opt cweight} variables whose 
number will determine how many outcome placements will be generated for each {varlist} variable. Those 
outcome variables will be given compound names derived by prefixing the name of the input variable with 
the name of the weight variable, separated by an underscore character. Any such optional prefix will override 
any corresponding {opt cwe:ight} option. See that {help genplace##Options:option} (below) for more details. The 
number and nature of these weights can be varied from varlist to varlist, depending on
those outcome variables will be named by prefixing, with the relevant cweight varname, the name of the 
input variable placed while using that weight. So the user might place a government in terms of its position 
regarding each of a number of policies that are given different weights in that placement. 
This means that the battery-names listed in {it:varlist} must be batteries of items that pertain to the 
same object. Only the user can verify that this is the case.

{pstd}
SPECIAL NOTE COMPARING {help genplace:{ul:genpl}ace} WITH {help genmeans:{ul:genme}anstats}: The data 
processing performed by the first step of a two-step {cmdab:genpl:ace} command (see NOTE 2 above) is 
computationally identical to that performed by command {cmdab:genme:ans} but conceptually very 
different. The command {cmdab:genme:ans} generates means and other statistics for numeric variables 
without regard to any conceptual grouping of variables inherent in batteries that might contain (some 
of) those variables. The command {cmdab:genpl:ace} can do the same for variables that are conceptually 
connected by being members of a battery of items but then proceed to a second step in which those means 
(or some other indicator values, weighted according to option {bf:cweight}) are used to average the 
item placements into a (weighted) mean placement regarding the battery as a whole (for example a 
legislature placed in left-right terms according to the individual placements of parties that are 
members of that legislature). Use of the standard [{help if}] component of the {cmdab:genpl:ace} 
command line can focus the generic placement on certain members of the battery (perhaps government 
parties, thus placing a government in left-right terms).

{pstd}
SPECIAL NOTE ON WEIGHTING. The {help genplace:{ul:genpl}ace} command places higher level objects in terms 
of the scale positions of lower level objects. Thus a political party might be placed in left-right 
terms by averaging the left-right placements it receives from respondents. When characterizing a 
higher-level object in terms of lower-level scores, those scores may need to be weighted. For example, 
survey respondents may need to be weighted according to their probabilities of being sampled. But if 
the party placements themselves are averaged across a legislature so as to place that legislature in the 
same left-right terms, it will generally be more appropriagte to use weights measured at a higher level of 
aggregation: perhaps the proportion of legislative seats controlled by that party. And if the party placements 
did not derive from respondents but from some external source (experts or manifestos or election outcomes, 
perhaps) then respondent weights will be irrelevant. Thus, if survey responses are used to place a 
government in left-right terms then the appropriate weight might be the proportion of ministries received 
by each party comprising that government. This is why {cmdab:genpl:ace} uses two different types of weight 
variable: one named in the {cmdab:genpl:ace} command line's [{help weight}] expression for weighting 
(generally) unit-level items and the other named in {cmdab:genpl:ace}'s {help genplace##Options:cweight} 
option for weighting higher-level items. More than one cweight variable can be listed, resulting in more 
than one outcome variable for each input variable being placed.

{pstd}
{bf:USING MULTIPLE INDICATORS OR CWEIGHTS:} As with {cmd:stackMe}'s command {cmdab:genii:mpute}, the optional 
prefix introducing the {cmdab:genpl:ace} command's {varlist} can list more than a single variable. When 
defining multiple indicators the purpose is evident: each prefix variable indicates a different pattern of 0,1 
codes that determine which stacks will contribute to the indicator's measured value. Regarding multiple cweights, 
as mentioned above, where stack-level data relating to political parties are used to place higher-level political objects such as governments, parliaments or policies, a number of different sources might supply relevant weights 
(e.g. votes cast, seats or ministries controlled, etc.). Other research traditions may find similar diversity 
in weighting criteria (education researchers might weight academic outcomes by class-size, student-age, 
average expenditure per student, and so on). In electoral studies, and perhaps elsewhere, effects of 
different weighting strategies have hardly been studied so {cmdab:genpl:ace} has been designed to permit 
multiple hypotheses regarding optimal weighting strategies to be readily tested.

{marker Options}
{title:Options}
{marker indicatorvars}
{p 2}{ul:Placement options}{p_end}
{p2colset 5 9 9 2}
{synopt :{opt ind:icator(varlist | varname if exp)}} if present, a (list of 0,1) indicator variable(s) 
identifying the stacks that will contribute to placing the object(s) named by the indicator(s) on the basis of 
mean values of indicated (=1) stacks (for example, government parties can be indicated by coding government 
parties =1 and other parties =0). Alternatively, the keyword {bf:if} followed by a logical expression can 
generate a singe {help tempvar}coded 1 if the expression is true and 0 otherwise. {bf:NOTE} that any indicator 
variable(s) established by this option is overridden by corresponding variable(s) named in a prefixvar list 
prepended to the {cmdab:genpl:ace} {varlist}. In the absence of any such indicator(s) the stacks themselves 
are placed on the basis of mean values of indicated stacks. No indicator vars can be optioned if cweight vars 
are optioned.{p_end}
{p 8 8 2}{space 3}If desired indicator variables do not yet exist (and more than just the one indicator is wanted 
than can be coded by this option's logical expression) those variables need to be generated or produced using 
Stata's {cmd:recode} command before invoking {cmdab:genpl:ace}. To take an example from electoral studies, such 
a generated indicator could be used to place an institution such as "the government" in terms of the electoral 
support given to parties that are members of that government.{p_end}
{marker cweight}
{phang}
{opth cwe:ight(varlist)} if present, a (list of) weight variable(s), constant across battery units (hence the 
initial letter 'c'), used to place each stack or higher-level indicator according to the context-specific 
placements provided by experts or other outside sources (in voting studies perhaps party platforms/manifestos). 
No cweight vars can be optioned if indicator vars are optioned.{break}
{space 3}These weight variable(s) will often have been merged with the current dataset by using Stata's {help merge} 
command before invoking command {cmdab:genpl:ace}. {bf:NOTE} that any weight variable established by use of this 
option is overridden by corresponding variable(s) named in a prefix-list prepended to the {cmdab:genpl:ace} {varlist} 
(the next option elaborates).

{phang}
{opt wtp:refixvars} if present, a signal for {cmdab:genpl:ace} to interpret any prefixvars (preceeding the 
{cmd:genplace} varlist as naming a (set of) cweight variable(s) instead of naming a (set of) indicator variable(s) 
– the default.

{phang}
{opt stk:level} if present, a signal for {cmdab:genpl:ace} to ensure that working data passed to the command for 
processing is organized at the stack level of aggregation rather than at the (default) context level.

{phang}
{opt two:step} if present, generate the mean placement of each stack from unit-level data before generating 
battery-level placements (the extra step may be needed to provide mean values that are not otherwise 
available based on respondent perceptions). These perceptions will by default be rendered constant across 
units (unless the opion below is used to cancel the plugging process).

{phang}
{opt noplu:g} if present, disregard the normal {cmdab:genpl:ace} expectation that means calculated from 
unit-level data in the first step of a two-step process will be replaced by plugging values that have
been rendered constant across respondents (by plugging the original values, specific to each respondent, 
with constant plugging values derived from the relevant means). Instead allow placements to be based on 
the original responses, perhaps so as to facilitate research into consequences of survey artifacts 
(e.g. projection/assimilation effects) on the resulting placements.

{phang}
{opth call(SMsubprogram [args] | [, options])} invoke a user-written program by specifying, in the first 
argument, the name of the subprogram and, in subsequent arguments, either the the names of locals to be 
passed to that program as positional arguments or, following a comma, a standard Stata optionslist. See 
help {help genWriteYourOwn} for details and a model program that calculates polarization measures for a 
battery of position variables. NOTE that the program called can be {help SMmeanstats:{ul:SMmea}nstats}, 
a version of {cmd:stackMe}'s {cmdab:genme:anstats} command that has been tailored to handle a call from 
{cmdab:genpl:ace} in order to provide {cmdab:genpl:ace} with a range of alternative statistics with which 
to replace all of what would otherwise have been mean values.{p_end}

{phang}
{opth call(SMiyield iyprefix iysupport iycred)} invokes another model for a user-written program – this one 
assuming the presence of set(s) of issue support variables, presemably merged with the stacked data before this 
command was invoked. One of these sets is required and measures, for each issue for each respondent for each 
party, the extent to which the respondent prefers that party's position regarding that issue. A second set 
(desirable but not essential) measures the credibility of that party regarding that issue for each respondent. 
The command calculates the 'yield' in votes gained by party emphasis on each of a number of issues. It saves 
the resulting index in variables with {varname}s constructed by prepending (with "iy_" or another prefix 
provided in the second argument) the {it:iysupport} varlist. Issue yield index values are generated in the same "wide" format as the 
issue variables from which those yields are derived. They can be summarized in various ways for ensuing 
analyses or doubly-stacked so that issues become nested within parties within respondents. See help 
{help SMwriteYourOwn} for details.{p_end}

{p 2}{ul:Data structure options}{p_end}

{phang}
{opth con:textvars(varlist)} (normally unused) a list of variables defining each context (e.g. country and year) 
for each of which separate placements will be generated (same valued outcome for all units/respondents in each 
context). By default, context varnames are taken from a Stata .dta file "{help char:characteristic}" established 
by {cmd:stackMe}'s utility program {cmdab:SMcon:textvars} the first time this .dta file was {help use:used} by a 
{cmd:stackMe} command; so this option is required if the default is to be overriden.

{phang}
{opt nocon:texts} if present, disregard distinctions between contexts (stack distinctions, defined by the 
system variable {it:SMstkid} (see {help {ul:{genst}acks}) cannot be disregarded since these define the 
objects being placed by this command).{p_end}

{p 2}{ul:Outcome variable naming options}{p_end}

{phang}
{opth mp:refix(name)} THIS OPTION DOES NOT EXIT for genplace, since pm_-prefixes are only used for the names  
Of first-step variables needed in an optioned twostep {cmdab:genpl:ace} procedure.{p_end}.

{phang}
{opth pp:refix(string)} if present, prefix for the name of the stack variable (which was a stubname before 
stacking) that will identify the outcome variable holding generated placements for that stack (averaged 
across battery members). 

{phang}
{opth ipr:efix(string)} if present, prefix for the pre-existing or user-supplied variable named by the second 
{help genplace##options:option}, above, (default is "pi_"). The prefix and varname will, together, identify 
the generated placement ourcome variable for that indicator.

{p 2}{ul:Diagnostic options}{p_end}

{phang}
{opth lim:itdiag(#)} only display diagnostic reports for the first # contexts (by default report 
diagnostics for all contexts processed).{p_end}

{phang}
{opt nod:iag} equivalent to {opth limitdiag(0)}.{p_end}


{marker Examples}
{title: Examples:}

{pstd}The following command generates a battery of "pm_" prefixed [weight]-weighted means from respondent-rated 
party left-right positions and, based on those, a single "govt"-prefixed measure of the government's left-right 
location in each country, year, and stack (assuming country and year are the contexts named in the relevant 
data file characteristic). The "govt"-prefix substitutes for the default "pi"-prefix due to the final option 
in the example.{p_end}

{phang2}{cmd:. genplace plr, indicator(govt if govpty==1) twostep} iprefix(govt){p_end}

{pstd}The following command generates two measure of government location, one weighted by the proportion of 
votres received by each party and one by the proportion of seats. Each is named by prefixing the input variable 
name with the cweight variable name, separated by an underscore character.{p_end}

{phang2}{cmd:. genplace xlr, indicator(govt if govpty) cweight(voteprop seatprop)}{p_end}{break}

{pstd}The following command uses {cmd:genplace}'s {opt call} option to invoke an ostensibly user-written subprogram 
that calculates Issue Yield Indices for each stack party (De Sio and Weber 2014), building on the stack-level means 
generated in the first step of a two-step {cmd:genplace} command. The contextvars option would cause the calculation 
to ignore differences between years (assuming that country and year are the contexts named in the relevant data file 
characteristic).

{phang2}{cmd:. genplace vote, contextvars(cntry) twostep call(iyield iy_ issusupport issucred)}


{marker Generatedvariables}
{title: Generated variables}

{pstd}
{cmd:genplace} may save the following variables or sets of variables:

{p 4 22 2}
pm_{it:var} pm_{it:var} ... (or other prefix string set by option {opt mpr:efix}) (perhaps unit-weighted) battery
means, generated across (unit-specific) values for each stack, of each variable in {varlist} as a first step 
(see NOTE 3 above) towards a (second step) placement of each battery named by these variables.{p_end}

{p 4 22 2}
pp_{it:var} pp_{it:var} ... (or other prefix string set by option {opt ppr:efix}) (perhaps unit-weighted) 
placement values generated across battery means, for each variable in {varlist}, placing that battery 
in terms of the means of its (constant across units) member items for each battery.{p_end}

{p 4 22 2}
pi_{it:var} pi_{it:var} ... (or other prefix string named by option {opt ipr:efix}) (perhaps 
{it:cseight}-weighted) generated values that place indicator values in terms of corresponding battery means.{p_end}

{p 4 22 2}
{it:cweightvar_var} {it:cweightvar_var} ... outcome placements of items defined by indicator values (either at 
the battery level or some higher level of aggregation) established by {cmdab:genpl:ace}'s {opt ind:icator} option. 
The number of such outcome placements will be the product of the number of cweight vars and {varlist} vars.

{pstd}Such other variables as may be created by user-written programs, perhaps with variable prefixes 
established by the user program interface (see option {opt cal:l(iyield)} for an example).{p_end}


{marker Reference}
{title: Reference}

{pstd}
To understand the function of {opt call(iyield...)}, whose utility will likely not extend beyond the 
subfield of electoral studies) see:{break}
De Sio, L., and Weber, T. (2014). "Issue Yield: A Model of Party Strategy in Multidimensional Space." 
{it:American Political Science Review}, 108(4): 870-885.

