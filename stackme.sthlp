{smcl}
{cmd:help StackMe}
{hline}
*!  Updated help text for StackMe version 2.0 running on Stata 9.0 or (faster) on Stata 16.1.
{title:Title}

{p2colset 5 16 16 2}{...}
{p2col :StackMe {hline 2}}package of Stata commands for pre-processing creating and manipulationg  
stacked (see {help reshape long}) data-sets for hierarchical (multi-level) analysis{p_end}
{p2colreset}{...}

{title:Introduction}

{pstd}
The {cmd:stackme} package is a collection of tools for pre-processing and generating stacked 
({help reshape:reshape}d) data. In the academic subfield of electoral studies this type of 
analysis is closely associated with the use of PTV variables (hence the name chosen 
for the original {cmd:PTVTools} package that evolved into {cmd:StackMe}); but specific StackMe 
commands are now mostly documented in more general terms, to accommodate usage across all 
academic fields of study that employ hierarchical (multi-level) datasets. 

{pstd}
{bf:IT IS IMPERATIVE} to keep track of whether your dataset is stacked or not and, if stacked, what 
is the "stack identification variable" (see {opt stackid} in {cmd:StackMe}'s {help genstacks}. We 
recommend you name the stack id at the start of the {help data label} for any dataset that is 
stacked. The {cmd:StackMe} command {help genstacks} will suggest an appropriate data label for any 
dataset it {help reshape}s.{p_end}

{pstd}
In electoral survey research, the PTV acronym refers to Propensities To Vote: batteries of items 
holding the self-reported probability that a respondent will {it:ever} vote for a specific 
political party (one probability for each party), and designed as indicators of what Downs (1957) 
referred to as "electoral utilities" (Downes, A. {it:An Economic Theory of Democracy}; see 
also van der Eijk, C. et al., {it:Electoral Studies} 2006; van der Eijk, C. and Franklin, 
M., {it:Elections and Voters}, Palgrave Macmillan 2009). But the same tools can be very helpful 
when preparing virtually any dataset for multilevel analysis.{p_end}

{pstd}
Such analyses make rather special demands both in terms of methods of analysis and in terms 
of the data being analysed. {cmd:StackMe} pre-processes relevant (often survey) data in a 
variety of ways to prepare it for ensuing hierarchical (multi-level) analyses.{break}

{pstd}
Firstly, data {it:stacking} is usually involved, implying that - in Stata terminology - analysis 
may call for data in {it:long} rather than in {it:wide} format (see Stata's {bf:{help reshape:reshape}}; 
command) and analysis may focus on {it:response}-level data rather than {it:respondent}-level data, 
with responses (at the lowest level of analysis) nested (stacked) within respondents. 
However, StackMe facilitates the reshaping of a dataset with multiple contexts (e.g. countries)
each with possibly different numbers of items (e.g. political parties) in the battery(ies) to be 
stacked. Batteries of different lengths imply missing data for all cases in certain contexts, 
a structure that would be hard to accommodate without elaborating Stata's native commands. After 
stacking (reshaping), each respondent is represented by multiple rows in the data matrix, one for 
each response that, before stacking, was not entirely missing.{break}
   NOTE: In conventional comparative survey data (e.g. the European Social Survey or surveys 
post-processed by the Comparative Study of Electoral Systems) a fair number of question 
batteries are largely empty so as to accommodate data from countries whose surveys had 
larger numbers of battery items (e.g. political parties). After reshaping, such surveys produce 
many rows that are missing for all but respondents from a single (or very few) countries. 
StackMe avoids burdoning memory and filespace with rows that consist entirely of missing data 
due to such happenstances.{break}

{pstd}
Secondly, the dependent variable is usually generalized to accommodate multiple contexts. Thus, 
while in electoral studies conducted in one country a researcher might seek to answer a research 
question such as "why do people vote Conservative?", with multiple countries having different 
party systems that question might need to be reconceptualized in terms of votes for a 
{it:generic} party – {it:any} party – with a question like "why do parties receive electoral 
support?" Such reconcptualization involves moving up the ladder of conceptual generality, which a
lso happens when "father" is viewed as a "family member" or 
"school" is viewed as an "educational establishment". Such reconceptualizations produce 
comparability across contexts if these involve different party systems or family structures or 
educational systems, as is common. They also affect {it:independent} ({it:input}) variables, which 
have to be reformulated to focus on their affinities with the dependent ({it:outcome}) variable 
before they can be used in a stacked analysis. {cmd:StackMe} generates two types of affinity: 
proximities (inverted distances) – see {help gendist:gendist} – and, for non-spatial items, 
so-called {it:y-hat}s – see {help genyhats:genyhats}. The original purpose was to facilitate use 
of ptv analysis as a substitute for discrete choice modeling, employing directly-measured 
preferences (utilities) rather than deriving these retrospectively from analysis of choices 
made. But analysis of discrete choice data can benefit just as much from many of the facilities 
that {cmd:StackMe} provides.


{title:Description}

{pstd}
The {cmd:stackMe} package includes the following commands:

{p2colset 5 17 19 2}{...}
{p2col :{bf:{help geniimpute:geniimpute}}}(Context-wise) incremental simple or multiple imputation of 
missing data within a battery of variables, taking advantage of within-battery interrelationships. 
The second "i" in "iimpute" stands for "inflated" as {cmd:geniimpute}. By default imputed values are 
inflated by random perturbations that permit {it:iimputed} data for multiple contexts to substitute 
for multiply-imputed duplicate datasets employed in Stata's {bf:{help mi:mi}} suite of commands.{p_end}
{p2col :{bf:{help genstacks:genstacks}}}(Context-wise) reshaping of a dataset for response-level 
analysis{p_end}
{p2col :{bf:{help gendist:gendist}}}(Context-wise) generation of distances between a 
spatially-located variable and each item in a battery of spatial items, with customizable 
treatment of missing data{p_end}
{p2col :{bf:{help genyhats:genyhats}}}(Context-wise) generation of {it:y-hat} affinity measures 
linking indepvars to ptvs or other depvars{p_end}
{p2col :{bf:{help gendummies:gendummies}}}generation of set(s) of dummy variables employing, as 
numeric suffixes for names of variables in each set, the numeric values actually found{p_end}
{p2col :{bf:{help genmeans:genmeans}}}generation of (optionally weighted) means of variables within 
contexts (similar to Stata's {help egen:{bf:egen}} command with the {bf:by} option, but 
permitting calculation of weighted means){p_end}
{p2col :{bf:{help genplace:genplace}}}generation of spatial placements at the battery level 
(e.g. legislature or government level if the battery items relate to political parties). Placements 
can optionally be weighted by the (weighted) number of respondents and/or by substantively 
meaningful weights (e.g. proportions of seats or of ministries controlled by parties that are members 
of a government).{p_end}

{pstd}
These tools largely duplicate existing commands in Stata but operate on data with multiple contexts 
(eg. countries or country-years), each of which need to be pre-processed separately. Moreover, all of the 
commands in {cmd:stackme} have additional features not readily duplicated with existing Stata commands 
even for data that relate to a single context. If the {cmd:contextvars} option is not specified, each of 
those individual commands treats the data as belonging to a single context.

{pstd}
The commands take a variety of options, as documented in individual help files, some with quite 
cumbersome names. However, ALL options can be abbreviated to their first three characters and many 
can be omitted (as documented).

{pstd}
The commands also save a variety of indicator variables (as documented). Most of these start with an 
underscore character and can be deleted by "drop _*" if the user does not want them to clutter a dataset. 
Three variables created by the command {help genstacks:genstacks} are needed by other tools and do not 
start with the underscore character. These are  genstacks_stack, genstacks_item and genstacks_nstacks.


{title:Workflow}

{pstd}
The {cmd:genstacks} command always operates on an unstacked dataset, reshaping it into stacked {help 
reshape}d format. Other commands may operate on either stacked or unstacked data, except that 
{help genplace:{bf:genplace}} requires stacked data because the objects it places in spatial terms are 
stacked batteries. No facility is provided for unstacking a previously stacked dataset (a crude way to 
do this would be to drop all stacks beyond the first).{break}

{pstd}The commands {cmd:gendist} and {cmd:genyhats} by default assume the data are 
stacked and treat each stack as a separate context, to be taken into account along with any 
higher-level contexts. These commands can, however, be used on unstacked data or they can be directed to 
ignore the stacked structure of the data by specifying the {cmd:nostack} option. This option has no effect 
on {cmd:gendummies} or {cmd:genmeans} or on any StackMe command that is being used on unstacked data 
(since unstacked data have only one stack per case). With stacked data, ignoring the separate contexts 
represented by each stack might make sense if exploratory analysis had established that there 
is no stack-specific heterogeneity relevant to the estimation model for which the data were being  
pre-processed. Alternatively, the user might employ this option so as to iimpute a variable that is 
completely missing in one or more stacks (e.g. particular choices asked only regarding a subset of  
parties).{break} 

{pstd}For logical reasons some restrictions apply to the order in which commands can be issued. 
In particular:{p_end} 

{pmore}(1) {cmd:geniimpute}, when used for its primary purpose of imputing (variance inflated) missing values 
for a battery of items, requires the data to {bf:not} be stacked, since members of that battery 
(eg. PTVs) are used to impute missing data for other members of the same battery; 

{pmore}(2) {cmd:gendist} can be useful in plugging missing data for items that can then be named in 
{cmd:iimpute}'s {bf:addvars} option to help in the imputation of missing data for other variables;

{pmore}(3) if {cmd:gendist} is employed after stacking, the reference items to which distances are computed 
have themselves to first have been {help reshape}d into long format by stacking them; and finally

{pmore}
(4) After stacking and the generation of y-hat affinity variables, the number of variables required for 
a final (set of) {help mi:{bf:mi}} command(s) will generally be greatly reduced, cutting the time needed 
to perform multiple imputations for what are generally very large datasets.

{pstd}
Consequently, a typical workflow would involve using {cmd:geniimpute} to fill out any batteries of 
conceptually-linked items by plugging their missing values, followed by {cmd:genstacks} to stack 
the data. Often this would be followed by {cmd:gendist}, used to plug missing values on item 
location variables and generate distance measures. Then{cmd:genyhats} might be used to transform 
indeps (those not already made tractable by being transformed into distance measures) into y-hat 
affinities with the stacked depvar. The results might then be used in a final (set of) {help 
geniimpute} commands to cull remaining missing data (the alternative of employing Stata's 
{help mi:{bf:mi}} command(s) might be preferred – but see SPECIAL NOTE ON MULTIPLE VERSUS SINGLE 
IMPUTATION in the help file for {bf:{help geniimpute}).{break} 

{pstd}
Considerable flexibility is available, however, to transform a dataset in any sequence thought 
appropriate, since any commands except for {cmd:genstacks} and {cmd:genplace} can be employed either 
before or after stacking ({cmd:genstacks} only before and {cmd:genplace} only after stacking).  
Moreover, the researcher can use the {cmd:nostack} option to force the production of distances, y-hats 
and missing data imputations that "average out" contextual differences by regarding all 
stacks (and perhaps also certain higher-level contexts) as a single context. This 
might make sense after preliminary analyses had established that there were no significant 
differences between these contexts in terms of the behavior of variables to be included 
in an estimation model. For example, country-year contexts are often collapsed into year 
contexts for (cross-section) time-series analyses and this happens automatically if the country 
id variable is omitted from a {bf:contextvars} option that contains a sequence variable).


{title:Variable naming conventions} 

{pstd}
StackMe commands expect battery variables to be named in one of two different 
ways, depending on whether the command is issued before or after stacking. 
Before stacking, variables from batteries of questions, one battery question for each battery item (for 
instance regarding different political parties), are expected to all have the same stub-name, with 
numeric suffixes that generally run from 1 to the number of items in the battery. Users with variable 
batteries whose items have disperate names (or stubnames with alphabetic suffixes) will need to rename 
such variables before using {cmd:StackMe} commands (see help {help rename group} and search on "addnumber".{break} 
{space 3}After stacking, each battery of variables becomes a single (stacked – 
{space 3}After stacking, each battery of variables becomes a single (stacked – 
what Stata referres to as {help reshape:reshape}d variable) named by the original stubname. So what was a 
{varlist} (of battery items) before stacking becomes a single battery variable after stacking. Note that 
the {help genstacks} command, which {help reshape}s variables from pre-stacking 
to post-stacking format, uses post-stacking conventions for the names of variables to be stacked (implied 
pre-stacking names are derived internally).{break} 
{space 3}At a third stage, resulting batteries may be "placed" in terms  
of their position on a concept or entity that underlies the battery (by using the {cmd:StackMe} command 
{help genplace:genplace}) with each such "placement" being given a new name reflecting the entity being 
placed (in electoral studies perhaps a political party or government).


{title:Variable lists and option lists}

{pstd}
Any StackMe command name can be followed by a standard Stata {varlist},
naming the variable(s) to be pre-processed by the command concerned. Several of these commands additionally 
offer an alternative {varlist} format that permits variables to be grouped into batteries by use of so-called 
"pipes" ({bf:"||"}) that separate the variables belonging to each battery. Where appropriate, each battery 
can be associated with an indicator variable (a {varname}, suffixed by a colon, that preceeds the {varlist} of 
battery-members), for example:{p_end}

{pstd}
{opt gendist} [{help varname:selfplace}:] {varlist} [{cmd:,} {it:options}] [ {bf:||} [{help varname:selfplace}:] 
 {help varlist} [{cmd:,} {it:options}] ... ]


{pstd}
{opt Option} list(s) that accompany such multiple {varlist}s, can be positioned as follows:

{pmore}(1) they may be placed following the final {varlist} in the sequence of {varlist}s, in which case the 
options listed there apply to all preceeding {varlist}s as well as to the final one; or{break}

{pmore}(2) they may be placed following the first {varlist}, in which case the options listed there apply to 
that {varlist} and to all subsequent {varlist}s; but the user can override individual option(s) by appending 
an {opt option}-list to any subsequent {varlist}(s) (including the final {varlist}) listing any option(s) 
that are to be added or changed. 


{title:Note regarding version 2.0}

{pstd}
{cmd:StackMe} 2.0 is actually version 2 of what was originally called {cmd:ptvtools}. It differs from 
{cmd:ptvtools} in having additional commands ({help genmeans:genmeans}, {help genplace:genplace}) and a 
user interface that is the same across {cmd:stackme} commands (pipe-delimited {varlist}s are available with 
all {cmd:stackme} commands rather than just for {cmd:genyhats}). The interface also provides additional 
functionality ({bf:options} that can be updated for {varlist}s beyond the first). More importantly, many 
{cmd:stackme} commands run faster by an order of magnitude (even faster for Stata versions 16.0 or later, 
which offer data frame technology. Initially we are distributing a beta version 1.0 which may still contain 
bugs and infelicities. Any comments and/or suggestions for improvements should be emailed to 
mark.franklin@trincoll.edu (if no response after a week, email the first author named below).{break}
   

{title:Authors}

{pstd}
Lorenzo De Sio - European University Institute (now LUISS);{break}
Mark Franklin - European University Institute (now emeritus at Trinity College Connecticut);{break}
includes previous code and other contributions by Elias Dinas


{title:Citation}

{pstd}
If you use {bf:stackMe} in published work, please use the following citation:{break}
De Sio, L. and Franklin, M. (2011) "StackMe: A Stata package for analysis of multi-level data" 
(version 2.0), {it:Statistical Software Components}, Boston College Department of Economics.
