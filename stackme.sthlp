{smcl}
{cmd:help StackMe}
{hline}

{title:Title}

{p2colset 3 14 14 2}{...}
{p2col :{bf:StackMe} {hline 2}}package of Stata commands for pre-processing, creating, and 
manipulating  stacked ({help reshape}d) data-sets for hierarchical (multi-level) analysis{p_end}
{p2colreset}{...}

{marker Introcuction}
{title:Introduction}

{pstd}
The {cmd:stackMe} package is a collection of tools for generating and manipulating stacked 
({help reshape:reshape}d) data. In the academic subfield of electoral studies, where StackMe was 
designed, reshaping usually involves what are referred to as "batteries" of survey items that 
result from asking the same survey question about each of a number of conceptually-connected 
reference-items, often political parties. Each respondent to the survey provides a set of answers 
to each battery of questions, producing a corresponding battery of variables in the resulting 
dataset. If the same questions were asked about five political parties there would be five 
responses in each battery at the respondent lavel of analysis. This way of organizing the data 
is referred to by Stata as "wide" format. But, for many purposes, one might want a separate 
case for each response, with the variables being "stacked" on top of each other in what Stata 
refers to as "long" format. Such "reshaping" increases the number of cases in the data (fivefold 
in this example) and changes the level of analysis from the respondent level to the response 
level. So, in the vocabulary used by {cmd:StackMe}, batteries of variables are intimately 
connected with stacks of variables, one being the long- format counterpart to the same data in 
the other (wide) format.

{pstd}
{bf:IT IS IMPORTANT} to keep track of whether your dataset is stacked or not and, if stacked, what 
is the "stack identification variable" (see option {opt sta:ckid} in {cmd:StackMe}'s {help genstacks}' 
help text). In datasets stacked by {cmd:stackMe}'s {help genstacks} this variable is named SMstkid 
by default, and it is recommended that this name not be changed. The stackid generally identifies 
the battery item that corresponds to each stack but if it does not then a variable must be
created (if it does not already exist) that contains the identifiers of the battery items and 
this variable must be named in the {opt ite:mname} option. That name is stored  
in the first word of the data label of any dataset stacked by {cmd:stackMe}'s {help genstacks}, 
before whatever label might already have identified the data before stacking.{p_end}

{pstd}
Analysis of hierarchical data makes rather special demands both in terms of methods of analysis and 
in terms of the data being analysed. {cmd:StackMe} manipulates relevant (often survey) data in a 
variety of ways to prepare it for ensuing hierarchical (multi-level) analyses.{break}

{marker Datastacking}
{pstd}
{bf:1) Data stacking}{break}
Firstly, data {it:stacking} is usually involved, implying that - in Stata terminology - analysis 
may call for data in {it:long} rather than in {it:wide} format, as explained above. After 
stacking ({help reshape}ing), each respondent is represented by multiple rows in the data matrix, 
one for each response that, before stacking, was not entirely missing. Given this need,
StackMe facilitates the reshaping of a dataset with multiple contexts (e.g. countries)
each with possibly different numbers of items (e.g. political parties) in the battery(ies) to be 
stacked. Batteries of different lengths imply missing data for all cases in certain contexts.{break}
{space 3}In conventional comparative survey data (e.g. the European Social Survey or surveys 
post-processed by the Comparative Study of Electoral Systems) a fair number of question 
batteries are largely empty so as to accommodate data from countries whose surveys had 
larger numbers of battery items (e.g. political parties). After reshaping, such surveys produce 
many rows that are entirely missing for all but respondents from a single (or very few) countries. 
StackMe avoids burdoning memory and filespace with rows that consist entirely of missing data 
due to such happenstances.{break}

{marker Genericvariable}
{pstd}
{bf:2) Generic variable analysis and affinity measures}{break}
Critically, the dependent variable is usually generalized to accommodate multiple contexts. Thus 
while, in electoral studies conducted in one country, a scholar might seek to answer a research 
question such as "why do people vote Conservative?", with multiple countries having different 
party systems that question will generally need to be reconceptualized in terms of votes for a 
{it:generic} party – {it:any} party – with a research question like "why do parties receive electoral 
support?" Such reconceptualization involves moving up the ladder of conceptual generality, which 
also happens when "newspaper" is viewed as a "media outlet" or "school" is viewed as an "educational 
establishment". Such reconceptualizations produce comparability across contexts if these involve 
different party systems or media structures or educational systems, as is common. They also affect 
{it:independent} ({it:input}) variables, which have to be reformulated to focus on their affinities 
with the dependent ({it:outcome}) variable before they can be used in a stacked analysis. {cmd:StackMe} 
generates two measures of affinity: proximities – inverted distances (see {help gendist}) – and, for 
non-spatial items, so-called {it:y-hat}s (see {help genyhats}). The original motive for facilitating 
the construction of these types of affinity measures was to encourage research employing PTV (for 
Propensity To Vote) measures, derived from survey data, as a substitute for discrete choice modeling 
from analysis of choices made (van der Eijk et al., 2006). But analysis of discrete choice data can 
benefit just as much from many of the facilities that {cmd:StackMe} provides.{break}

{marker Affinitymeasures}
{pstd}
{bf:3) Affinity measures in doubly-stacked data}{break}
This type of datastructure is relevant to the 
analysis of hierarchical (multi-level) data in any discipline; but we introduce the concept with 
benefit of an example from our own subfield. In electoral studies, as well as batteries of 
party-related questions, there can also be batteries of issue-related questions. Issues are of relevance 
not only to respondents (who often have preferences as between issues) but also to parties (that 
often take positions in regard to issues). Issue batteries can be stacked either within parties or 
within respondents; but if they are stacked within parties that are already stacked within 
respondents then the data becomes doubly-stacked and the stacking of issues within parties within 
respondents can be used to link parties to respondents via the issues that both have in common, 
facilitating studies of issue-based party choice.{break}
{space 3} There are no established procedures for handling affinities in doubly-stacked data, so 
anyone wanting to attack this frontier of research in their own academic discipline is free to design 
their own approach, perhaps helped by the examples provided of our own approach to doubly-stacked 
data in the subfield of electoral studies. These examples take the form of "user-provided programs" 
that can be "hung" onto "hooks" that we have provided, in {cmd:StackMe}'s {help genplace} command, 
designed to facilitate the incorporation into {cmd:stackMe} of new code operationalizing whatever 
new insights may arise. See the help texts for {help genplace} and for {help genWriteYourOwn} for 
details.{break} 

{marker Programefficiency}
{pstd}
{bf:4) Program efficiency}{break}
Multi-level comparative datasets constructed from survey data across multiple countries over 
increasingly lengthy spans of time can be huge. Standard data analysis procedures with such data 
can be very time-consuming. For one-off estimation analyses these costs must be born, but for 
data management tasks that will be repeated multiple times it is worth taking the trouble to come 
up with (and learn to benefit from) procedures that maximize Stata's strengths even at the cost 
of heavy outlays of time for program-design and coding, for suites of Stata commands such as 
the suite documented here. {cmd:StackMe} has been operationalized on the basis of extensive 
experimentation to minimizing processing time especially for operations that will need to be 
repeated for a large proportion of variables in a survey-based dataset. The syntax innovations 
adopted for {cmd:StackMe} commands are designed to facilite the processing of as many variables 
as possible on a single pass through the data, permitting programming strategies that minimize 
execution time.


{marker Description}
{title:Description}

{pstd}
The {cmd:stackMe} package includes the following commands:

{p2colset 5 17 15 2}{...}
{p2col :{help geniimpute:{ul:genii}mpute}}(Context-wise) incremental simple or multiple imputation of 
missing data within a battery of variables, taking advantage of within-battery interrelationships. 
The second "i" in "iimpute" stands for "inflated" as, by default, imputed values are inflated by 
random perturbations that permit iimputed data for multiple contexts to substitute for multiply-imputed 
and duplicated datasets employed in Stata's {bf:{help mi:mi}} suite of commands.{p_end}
{p2col :{help gendummies:{ul:gendu}mmies}}generation of set(s) of dummy variables employing, as 
numeric suffixes to the names of variables in each set, the numeric values that {cmd:gendummies} 
actually finds in the data{p_end}
{p2col :{help genstacks:{ul:genst}acks}}(Context-wise) reshaping of a dataset for response-level 
analysis (see the relevant introductory paragraph above){p_end}
{p2col :{help gendist:{ul:gendi}st}}(Context-wise) generation of distances between spatially-located 
self-placement variables and each member of a corresponding battery of spatial items, with customizable 
treatment of missing data{p_end}
{p2col :{help genyhats:{ul:genyh}ats}}(Context-wise) generation of {it:y-hat} affinity measures that 
connect {help indepvars} to {help depvars}{p_end}
{p2col :{help genmeans:{ul:genme}ans}}generation of (optionally weighted) means of variables within 
contexts – similar to Stata's {help egen} command with the {bf:by} option, but permitting calculation 
of weighted means{p_end}{p2col :{help genplace:{ul:genpl}ace}}generation of (generally spatial) 
placements at the battery-level (e.g. legislature- or government-level of the battery items relate to 
political parties). Placements can optionally be weighted by the (weighted) number of respondents 
and/or by substantively meaningful weights (e.g. proportions of seats or of ministries controlled by 
parties that are members of a government).{break}{space 3}{cmd:genplace} also serves as an 
{bf:interface for user-written programs} that can ganerate additional or alternative variables that 
place battery items (or batteries as entities in themselves) in terms of user-specified concepts 
(e.g. polarization). An example of a user-written command is supplied, which generates 
{it:Issue Yield Index} values for battery items assumed to be political parties (De Sio and Webber 
2014). See help {help genWriteYourOwn} for details.{p_end}{p2col :{help genid:{ul:genid}}} a 
{it:{bf:utility}} (not a {it:{bf:command}}) that extracts stack, item and/or N-of-stacks identifier 
name(s) from the data label of the currently {help use}d dataset, with options to rename any or all 
of these and save the resulting indicators back into the data label of the same currently {help use}d 
dataset.{p_end}

{pstd}
The functionality of these tools can largely be emulated using existing Stata commands but those would in 
many cases require multiple steps (or call for advanced programing skills) in order to operate on data with 
multiple contexts (eg. countries or country-years), for each of which the data may need to be pre-processed, 
or otherwise manipulated, separately. Moreover, many of the commands in {cmd:StackMe} have additional 
features not readily duplicated with existing Stata commands, even for data that relate to a single context.

{pstd}
The commands take a variety of {help options}, as documented in individual help files, some with quite 
cumbersome names. However, ALL options can be abbreviated to their first three characters and many can be 
omitted (as documented).

{pstd}
The commands save a variety of indicators and measures, most of them being given {varname}s based on the names 
of the variable(s) from which they are derived (as documented). Three variables created by the command 
{help genstacks} are needed by other {cmd:StackMe} commands and do not start with the underscore character. 
These are {it:stackme_stk} (the stack identifier), {it:stackme_itm} (the identification code originally given 
to each battery variable before these were {help reshape}d into stacks) and {it:stackme_nst} – the total number 
of stacks, some of which might be all-missing (and thus not present) in certain contexts. The names of these 
three variables are held in the first word of the data label for any dataset stacked by {help genstacks}. A 
special- purpose {cmd:StackMe} utility ({help genid:{ul:genid}}) serves to extract, rename and/or replace these 
ids in the data label of the currently {help use}d dataset.

{marker Workflow}
{title:Workflow}

{pstd}
The {help genstacks} command normally operates on an unstacked dataset, {help reshape}ing it into stacked 
format (but it may also be used to "doubly-stack" an already stacked dataset). Other commands may operate 
on either stacked or unstacked data, except that {help genplace:{ul:genpl}ace} requires stacked data because 
the objects these commands {it:place} (in spatial terms) or {it:code} (in terms of other attributes) consist 
of stacked batteries. No facility is provided for unstacking a previously stacked dataset (a crude way to 
do this would be to {help keep} just a single stack for every original observation). So it is strongly 
recommended that users create and save a dofile containing the Stata code responsible for prepping and 
stacking a Stata data file.{break}

{pstd}The commands {help gendist:{ul:gendi}st}, {help genyhats:{ul:genyh}ats} and {help genplace:{ul:genpl}ace} 
by default assume that the data  are stacked and treat each stack as 
a separate context, to be taken into account along with any higher-level contexts. They can, however, be 
used on unstacked data and/or they can be directed to ignore the stacked structure 
of the data by specifying the {opt nos:tack} option. This option has no effect on 
{help gendummies:{ul:gendu}mmies} or {help genmeans:{ul:genme}ans} or on any 
{cmd:StackMe} command that is being used on unstacked data (since unstacked data only have one stack 
per case). With stacked data, ignoring the separate contexts represented by each stack might make 
sense if exploratory analysis had established that there is no stack-specific heterogeneity relevant 
to the estimation model for which the data were being  pre-processed. Alternatively, the user might 
employ this option so as to {help geniimpute:{ul:genii}mpute} a variable that is completely missing in 
one or more stacks (e.g. particular choices asked only regarding a subset of parties).{break} 

{pstd}For logical reasons some restrictions apply to the order in which commands can be issued. 
In particular:{p_end} 
{pmore}(1) {help geniimpute:{ul:genii}mpute}, when used for its primary purpose of imputing (variance inflated) 
missing values for a battery of items, requires the data to {bf:not} be stacked, since members of that battery 
(eg. PTVs) are used to impute missing data for other members of the same battery; 

{pmore}(2) {help gendist:{ul:gendi}st} can be useful in plugging missing data for items that can then be named 
in {help geniimpute:{ul:genii}mpute}'s {opt add:vars} option to help in the imputation of missing data for other 
variables;

{pmore}(3) if {help gendist:{ul:gendi}st}} is employed after stacking, the reference items from which distances 
are generated have themselves to have first been {help reshape}d into long format by stacking them; and finally

{pmore}
(4) After stacking and the generation of y-hat affinity variables, the number of variables required for 
a final (set of) {help geniimpute:{ul:genii}mpute} command(s) will generally be greatly reduced, cutting the time 
needed to perform missing data imputations for what are generally very large datasets.

{pmore}{bf:NOTE that processing time can be greatly reduced} by grouping together all {varlist}s that 
can be processed under control of a single set of {it:{help options}}. This is a general feature of {cmd:StackMe} 
commands, although the effect is most evident with {help geniimpute:{ul:genii}mpute} and {help genyhats:{ul:genyh}ats} 
– the two {cmd:StackMe} commands that make greatest demands on processing power because they are generally employed to 
pre-process such a large proportion of the variables in a stacked dataset. (The {help genstacks:{ul:genst}acks} 
command has also been greatly accellerated, but using a different programing strategy.){p_end}

{pstd}
Consequently, a typical workflow would involve using {help geniimpute:{ul:genii}mpute} to fill out any batteries of 
conceptually-linked items by plugging their missing values, followed by {help genstacks:{ul:genst}acks} to stack 
the data. Often this would be followed by {help gendist:{ul:gendi}st}, used to (optionally) plug missing values on 
item location variables and generate distance measures. Then {help genyhats:{ul:genyh}ats} might be used to transform 
indeps (those not already rendered tractable by being transformed into distance measures) into y-hat affinities with 
the stacked depvar. The results might then be used in a final (set of) {help geniimpute:{ul:genii}mpute} commands to 
cull remaining missing data (Stata's {help mi:{bf:mi}} command(s) might be viewed as an alternative; but see the 
section on {bf:multiple imputation} in the help file for {help geniimpute:{ul:genii}mpute}).{p_end} 
{pstd}
Considerable flexibility is available to transform a dataset in any sequence thought appropriate, since any 
commands except for {help genstacks:{ul:genst}acks} can be employed 
either before or after stacking ({cmd:genstacks} can be used to "doubly-stack" an already stacked dataset). Moreover, 
the researcher can use the {opt nos:tacks} and {opt noc:ontexts} options to force the production of distances, 
y-hats and missing data imputations that "average out" contextual differences by regarding all stacks (and perhaps 
also certain higher-level contexts) as a single context. This might make sense after preliminary analyses had 
established that there were no significant differences between these contexts in terms of the behavior of variables 
to be included in an estimation model. For example, country-year contexts are often collapsed into year contexts 
for (cross-section) time-series analyses and this happens automatically if the country id variable is omitted from 
a {opt con:textvars} option that contains a sequence variable.{p_end}

{marker Variablenaming}
{title:Variable naming conventions} 

{pstd}
{cmd:StackMe commands expect battery variables to be named} in one of two different ways, depending on whether 
the command is issued before or after stacking. Before stacking, variables from batteries of questions, 
one battery question for each battery item (for instance regarding different political parties), are 
expected to all have the same stub-name, with numeric suffixes that generally run from 1 to the number 
of items in the battery (e.g. parties that were asked about). Users with variable batteries whose items 
have disperate names (or stubnames with alphabetic suffixes) will need to rename such variables before 
using {cmd:StackMe} commands (see help {help rename group} especially rule 17).{break}
{space 3}{bf:After stacking, each battery of variables} becomes a single ({help reshape}d variable) named by the 
original stubname. So what was a {varlist} (of battery items) before stacking becomes a single battery 
variable after stacking. Note that, while the {help genstacks:{ul:genst}acks} command will accept {varlist}s 
of variables named in either fashion, using the post-stacking convention requires less typing and is more 
likely to bring common naming errors to light.{break}
{space 3}{bf:At a third stage}, resulting batteries may be "placed" in terms  of their position on the concept or 
entity that underlies the battery (by using the {cmd:StackMe} command {help genplace:{bf:{ul:genpl}ace}}, with each 
such "placement" being given a new name whose prefix reflects the entity being placed (in electoral studies 
perhaps a legislature or government). {help genplace:{bf:{ul:genpl}ace}} also provides a bridge to "doubly-stacked" 
datasets by providing "hooks" on which to "hang" user-written programs. See help {help genWriteYourOwn} for details.

{marker Variablelists}
{title:Variable lists and option lists}

{pstd}
Every StackMe command name should be followed by a Stata {varlist} ({help genstacks:{ul:genst}acks} has a 
{it:{help namelist}} alternative), naming the variable(s) to be pre-processed by the command concerned. Each of 
these commands additionally offers an alternative {varlist} format that permits variables to be grouped into 
batteries by use of so-called "pipes" ({bf:"||"}) that separate the variables belonging to each battery. Where 
appropriate, each battery can be associated with an indicator variable (a {varname}) or {varlist}, suffixed by 
a colon, that preceeds the {varlist} of battery-members) and each varlist will generally be followed by an 
{it:{help option}}list, for example:{p_end}

{p 5 14}
{opt gendi:st} [{help varname:selfplace}:] {varlist} {bf:[if][in][weight]}{cmd:,} {it:{help options}} [ {bf:||}
[{help varname:selfplace}:] {break}{help varlist} ... ]

{pstd}
The "{bf:{help [if]} {help [in]} {help [weight]},} {help options}" that follow the first such {varlist} sets 
expressions and options that 
apply to that {varlist} and to all subsequent {varlist}s (in practice these expressions and options can occur 
anywhere among the varlists concerned – not only following the first of them). But there can normally be only one 
single occurrence of "{bf:[if][in][weight],} {opt options}" for any {cmd:StackMe} command (see {bf:Hidden Gems}, 
below, for an exception).

{marker regardingversion2}
{title:Note regarding version 2.0}

{pstd}
As just implied, this release of {cmd:StackMe} is actually Version 2 of what was originally named {cmd:PTVtools} 
(the acronym stands for Propensity To Vote – see Eijk et al 2006). It differs from {cmd:PTVtools} in having 
additional commands – {help genmeans}, {help genplace} (which also provides an interface for user-written programs). 
It's user interface has been standardized across {cmd:StackMe} commands: pipe-delimited {varlist}s are 
available with all {cmd:StackMe} commands 
(except for {help genstacks}), not just with {cmd:genyhats}; all {cmd:StackMe} commands offer the same suite of 
options, invoked by the same option-names, to the extent that each option makes sense for the command concerned. 
The interface also provides additional functionality:{break} 
[{help if}], [{help in}] and [{help weight}] can now be employed with all {cmd:StackMe} commands (except for 
{help genstacks}), not just {help genmeans} and {help genplace}. More importantly, many {cmd:StackMe} commands 
run faster by an order of magnitude. This is especially true for {help genstacks}, {help geniimpute} and 
{help genyhats} (which are the commands most likely to involve all substantively relevant variables in a 
{cmd:StackMe} dataset).{break}{space 3}Initially we are distributing a beta version of {cmd:StackMe} 2.0, 
which may still contain bugs and infelicities. Any comments and/or suggestions for improvements should be 
emailed to mark.franklin@trincoll.edu (if no response within a week, email the first author named below).{break}

{marker Hiddengems}
{title:Hidden gems: StackMe data manipulation through the backdoor}

{pstd}
Two quasi-options, not documented elsewhere in the {cmd:StackMe} help text, serve in fact as directives for 
the {cmd:stackMe} command-processor not to flag an error when an additional "{cmd:[if][in][weight], options}" 
string is used with any StackMe command that allows multiple {bf:{varlist}}s.  {opt new:options} (alias 
{opt new:expressions}) can signal the presence of expression(s) and/or option(s) that cancel and replace 
whatever expressions and options were previously in effect for the current command; alternatively, 
{opt mod:options} (alias {opt mod:expressions}) can signal the presence of expression(s) and/or option(s) 
that add to and/or modify whatever expressions/options were previously in place for the current command. 
{opt mod:options} is the default option assumed if none of these options introduce the options-list.{p_end}
{pstd}{space 3}We should stress that these unusual directives must be placed at the start of any list of 
options – a list that may be otherwise empty if only an expression (e.g. the {cmd:weight} expression) is being 
added or changed. These backdoor {cmd:stackMe} conventions are not otherwise documented because they fly in the 
face of fundamental features of the Stata command language: (1) that only a single (set of) "{cmd:[if][in][weight]}" 
expression(s) can be associated with a Stata command, and (2) that options appended to a Stata command can be added 
to but not changed. The idea of modified or replaced options/expressions could be very confusing to Stata users and 
likely constitute a poor precedent. So the availability of this procedure is mentioned only for the benefit of 
users who are already well-acquainted with the Stata command language and without any specific guidance as to 
suggested usage.{p_end}
{pstd}{space 3} We believe that experienced Stata users with large numbers of variable batteries to pre-process 
will seize on the opportunities offered by these otherwise undocumented directives for simplifying the required 
commands, thus improving the documentation offered by Stata's {bf:History} file, without any need for specific 
guidance from us. (StackMe already introduces what might be considered the heretical innovation of commands 
that seemingly process the data multiple times using different variable lists, even though the true purpose 
of {cmd:StackMe}'s multiple {varlist}s is to perform multiple analyses on a single pass through the data).{p_end}
{pstd}{space 3}{bf:Note} that employing the directives {opt new:...} and/or {opt mod:...} negates that purpose. 
The appearance of an "{cmd:[if][in][weight], options}" string beyond the first does somewhat slow execution of 
the {cmd:stackMe} command to which the additional expressions/options are added. But this slow-down could be 
barely noticeable in context of the sort of dataset (deriving from a newly-fielded survey, for example) where 
these backdoor procedures might prove most useful.{p_end}


{title:Authors}

{pstd}
Lorenzo De Sio - European University Institute (now at LUISS);{break}
Mark Franklin - European University Institute (now emeritus at Trinity College Connecticut)


{title:Citations}

{pstd}
If you employ {bf:StackMe} in published work, please use the following citation:{break}
De Sio, L. and Franklin, M. (2011) "StackMe: A Stata package for analysis of multi-level data" 
(version 2.0), {it:Statistical Software Components}, Boston College Department of Economics.

{pstd}
To better understand generic variable analysis in a comparative framework see:{break}
Eijk, C. van der, Brug, W. van der, Kroh, M. and Franklin, M. (2006) "Rethinking the dependent variable 
in voting behavior: On the measurement and analysis of electoral utilities", {it:Electoral Studies} 
25(3): 424-447.
