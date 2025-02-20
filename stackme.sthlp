{smcl}
{cmd:help StackMe}
{hline}

{p2colset 3 14 14 2}{...}
{p2col :{bf:StackMe} {hline 2}}package of Stata commands for pre-processing and {help reshape}ing 
data, preparatory to multi-level or hierarchical (sometimes known as contextual) analysis.{p_end}
{p2colreset}{...}

{marker Introduction}
{title:Introduction}

{pstd}
The {cmd:stackMe} package is a collection of tools for generating and manipulating stacked 
{help reshape:(reshape}d) data. In the academic subfield of electoral studies, where StackMe was 
designed, reshaping is commonly employed to facilitate the analysis of multi-level (hierarchical)
data (see below). Indeed, use of {cmd:stackMe} is hardly called for with conventional data.

{marker Datastacking}
{title:Data Stacking}

{pstd}
This usually involves what are referred to as "batteries" of survey items 
that result from asking the same survey question about each of a number of conceptually-connected 
reference-items, often political parties. Each respondent to the survey provides a set of answers 
to each battery of questions, producing a corresponding battery of variables in the resulting 
dataset. If the same questions were asked about four political parties there would be four 
responses in each battery at the respondent level of analysis. This way of organizing 
the data is referred to by Stata as "{help reshape:wide}" format, as illustrated. 

              Wide     
    +------------------------+         Wide format layout of data regarding left-right positions 
    |  i  plr1 plr2 plr3 plr4|         (plr) of four parties, identified by numeric suffixes 1-4 
    |------------------------|         appended to the 'plr' stubs, for two respondents numbered 
    |  1   4.1  4.5  6.5 5.4 |         i=1 and i=2. Visually we see each of the four left-right 
    |  2   3.3  3.0  4.4 4.0 |	       party positions observed by each respondent as being 
    +------------------------+         "stacked", with i=1 responses above the i=2 ones.

{pstd}
But, for many purposes (some of them detailed below), one might want a separate observation for each 
response, with the stacks of responses being themselves "stacked" on top of each other in what Stata 
refers to as "{help reshape:long}" format. Such "reshaping" increases the number of observations in 
the data (fourfold in this example) and changes the level of analysis from the respondent level to 
the response level, as shown below.

        Long         
    +–––––––––––+         Long format layout of the same data as shown above. Note how the numeric 
    | i  j  plr |         suffixes that had distinguished specific 'plr#' variables have morphed into
    |–––––––––––|         values of the new 'j' variable, and how 'plr' has lost its suffixes since,
    | 1  1  4.1 |         in long format, the values that had been assigned to successive wide-format
    | 1  2  4.5 |         substantive variables are now assigned to successive cases in the one long-
    | 1  3  6.5 |         format substantive variable.
    | 1  4  5.4 |            Thinking of the four {bf:{it:plr}} columns in wide format as themselves being 
    | 2  1  3.3 |         stacks of observations, we might see the long-format {bf:{it:plr}} variable as being 
    | 2  2  3.0 |         a sort of "superstack" in which the wide-format {bf:{it:plr}}# variables have been 
    | 2  3  4.4 |         interleaved across individual respondents identified by different i-values. 
    | 2  4  4.0 |         In this "stack of stacks" each j-value identifies the wide-format stack that 
    +–––––––––––+         had previously housed that same observation (why 'j' is called a "stack id").

{pstd}
And note that the data-point concerned (for example the value 4.0, bottom right of each table) can be 
correctly called an "observation" in either format. The difference lies in who is making the observation 
– the reseacher who posed the question or the respondent who answered it. So, in the vocabulary 
used in survey research (and hence in this {cmd:StackMe} help text), batteries of responses are intimately 
connected with stacks of observations, one being the long-format counterpart to the same observation/response 
in wide format. Clearly, survey research gives us access to the observations of both respondents and 
researchers; but we need to configure the data correctly according to which is at the focus of our interest.

{pstd}
{bf:IT IS IMPORTANT} to keep track of whether your dataset is stacked or not and, if stacked, what 
is the "stack identification variable". In datasets stacked by {cmd:stackMe}'s {help genstacks:{ul:genst}acks} 
command, this variable is named {it:{cmd:SMstkid}} by default, and it is recommended that this name not be 
changed. This variable, the `j' variable in the above description of stacked data, 
generally identifies the battery item that corresponds to each stack but, if it does not, then a 
variable must be created (if it does not already exist) that links stacks to batteries (for example, 
party identification number). It is recommended that such links between stack IDs and battery items 
be named by the {opt ite:mname} option. The variable concerned will be added to the list of variables to 
be reshaped by {cmdab:genst:acks} so that the stacked counterpart can be used to define relevant 
linkages (for example when merging the stacked data with data from relevant archives). For a more detailed 
account of these linkage mechanisms see the Special Names section of this help text, below, and the help 
text for {help genstacks:{ul:genst}acks}.{p_end} 
{pstd}
Data stacking is often employed in statistical analyses involving hierarchical or multi-level 
(sometimes known as contextual) data, as already mentioned. Indeed, {cmdab:genst:acks} is mainly 
useful in such contexts. With a conventional dataset from a single context, the standard Stata 
{help reshape} command would be just as appropriate and (possibly) a tad faster.{p_end}

{pstd}
Analysis of hierarchical data makes rather special demands both in terms of methods of analysis 
and in terms of the data being analysed. {cmd:StackMe} manipulates relevant data (often survey 
data) in a variety of ways to prepare it for ensuing hierarchical (multi-level) analyses, calling 
for user familiarity with a number of additional technical terms and conventions.{p_end}

{marker Terms}
{title:Terms and conventions}

{pstd}
{cmd:StackMe} facilitates the reshaping of a dataset with multiple contexts (e.g. countries)
each with possibly different numbers of items (e.g. political parties) in the battery(ies) to be 
stacked. Batteries of different lengths imply missing data for all observations in certain 
contexts.{p_end}
{pstd}
{space 3} {bf:Empty batteries} In conventional comparative survey data (e.g. the European Social 
Survey or  surveys post-processed by the Comparative Study of Electoral Systems) a fair number of 
question batteries are largely empty so as to accommodate data from countries whose surveys had 
larger numbers of battery items (e.g. political parties). After reshaping, such surveys produce 
many observations that are entirely missing for all but respondents from a single (or very few) 
countries. StackMe avoids burdoning execution time with evaluations of rows that consist 
entirely of missing data due to such happenstances.{break}
{space 3} {bf:Battery boundaries} also have a number of implications relevant to the handling of 
{it:hierarchical data}. These arise because batteries of variables often have interrelationships 
(typically negative inter-correlations due to patterns in respondent preferences) that can 
affect multivariate analyses of any kind. For example, multivariate analyses are at the heart of 
imputation estimations which may be deliberately performed using unstacked data in order to take 
advantage of within-battery interrelationships when plugging observations for which answers to 
battery questions are absent.{break}
{space 3} {bf:Units and items} The malleability of data in terms of wide versus long format gives 
rise to ambiguity when referring to "observations", a word that changes its meaning with changes 
in the level of analysis. In {cmd:stackMe} we use the word "unit" to refer specifically to 
observations at the original level of analysis before stacking and the word "item" to refer 
specifically to the battery item that will become an observation after stacking.{p_end}

{marker Genericvariable}
{title:Generic variable analysis and affinity measures}

{pstd}
Critically, the dependent (outcome) variable is usually generalized to accommodate multiple contexts. 
Thus while, in electoral studies conducted in one country, a scholar might seek to answer a research 
question such as "why do people vote for the Labor party?", with multiple countries having different 
party systems that question will generally need to be reconceptualized in terms of votes for a 
{it:generic} party – {it:any} party – with a research question like "what explains the level of electoral 
support that parties receive?" Such reconceptualization involves moving up the ladder of conceptual 
generality, which also happens when "Sun-Times" is viewed as a "newspaper" or "Lincoln High" is viewed 
as an "school".  Such reconceptualizations produce comparability across contexts if these involve 
different party systems or media structures or educational systems, as is common. More importantly, the 
more general conceptualization inevitably results in more generally applicable explanations of social 
phenomena – what many would say is the primary benefit of comparative socio-political studies. But these 
more general explanations also require a more generic formulation of {it:independent} variables, 
(sometimes called {it:input} variables), which must be reformulated to focus on the process or mechanism 
that brings the two together, often referred to as the "affinity" that an indep shows for a depvar.

    +–––––––––––––––––––––––––––+
    | i  j  plr  rlr  dlr  prox |         Deriving proximity as a measure of affinity between
    |–––––––––––––––––––––––––––|         voters and parties in left-right terms. Variable plr
    | 1  1  4.1  2.2  1.9  8.1  |         is the same variable used earlier; rlr is respondent's 
    | 1  2  4.5  2.2  2.4  7.6  |         left-right position; dlr is the distance between rlr 
    | 2  1  3.3  6.5  2.3  7.5. |         and plr on a 10-point scale. Proximity, the final 
    | 2  2  3.0  6.5  4.2  5.8. |         variable, is inverse distance (10 - dlr), a measure of 
    +–––––––––––––––––––––––––––+         affinity between voters and parties in left-right terms.

{pstd}
{cmd:StackMe} generates three measures of affinity: proximities – inverted distances as shown above 
(see {help gendist:{ul:gendi}st}) – and, for non-spatial items, either dummy variables (e.g. "this is the party 
a respondent voted for", "this is the party a responded feels close to" – see {help gendummies:{ul:gendum}mies}) 
or so-called {it:y-hat}s (see {help genyhats:{ul:genyh}ats}). Easing the construction of such affinity 
measures was originally intended to encourage research employing PTV (for Propensity To Vote) 
measures, derived from survey data, as a substitute for discrete choice modeling from analysis of 
choices made (van der Eijk et al., 2006). But analysis of discrete choice data can benefit just as 
much from many of the facilities that {cmd:StackMe} provides.{break}

{marker Affinitymeasures}
{title:Affinity measures in doubly-stacked data}

{pstd}
This type of datastructure is relevant to the analysis of hierarchical (multi-level) data in any 
discipline; but we introduce the concept with benefit of an example from our own subfield. In 
electoral studies, as well as batteries of party-related questions, there can also be batteries 
of issue-related questions. Issues are of relevance not only to respondents (who often have 
preferences that vary between issues) but also to parties (that often take different positions 
in regard to issues). Issue batteries can be stacked either within parties or within respondents; 
but if they are stacked within parties that are already stacked within respondents then the data 
becomes doubly-stacked and the stacking of issues within parties within respondents can be used 
to link parties to respondents via the issues that both have in common, facilitating studies 
of issue-based party choice.{p_end}

{pstd}
There are no established procedures for handling affinities in doubly-stacked data, so 
anyone wanting to attack this frontier of research in their own academic discipline is free to design 
their own approach, perhaps helped by the examples provided of our own approach to doubly-stacked 
data in the subfield of electoral studies. These examples take the form of "user-provided programs" 
that can be "hung" onto "hooks" that we have provided, in {cmd:StackMe}'s {help genplace:{ul:genpl}ace} 
command, designed to facilitate the incorporation into {cmd:stackMe} of new code operationalizing 
whatever new insights may arise. See the help texts for {help genplace:{ul:genpl}ace} and for 
{help genWriteYourOwn} for details.{p_end}

{marker Programefficiency}
{title:Program efficiency}

{pstd}
Multi-level comparative datasets constructed from survey data across multiple countries over 
increasingly lengthy spans of time can be huge. Standard data analysis procedures with such data 
can be very time-consuming. For one-off estimation analyses these costs must be born, but for 
data management tasks that will be repeated multiple times it is worth taking the trouble to come 
up with (and learn to benefit from) procedures that maximize Stata's strengths, even at the cost 
of heavy outlays of time for program-design and coding. Such programming efforts give rise to 
suites of Stata commands such as the package documented here. {cmd:StackMe} has been operationalized 
on the basis of extensive experimentation to minimizing processing time especially for operations 
that will need to be repeated for a large proportion of variables in a survey-based dataset. The 
syntax innovations adopted for {cmd:StackMe} commands are designed to facilite the processing of 
as many variables as possible on a single pass through the data, permitting programming strategies 
that minimize execution time.{p_end}


{marker Description}
{title:Description}

{pstd}
The {cmd:stackMe} package includes the following commands, all of which can be abbreviated to their 
first five characters (but only those first five characters or the full name are valid commands):

{p2colset 5 18 16 2}{...}
{p2col :{help geniimpute:{ul:genii}mpute}}(Context-wise) incremental simple or multiple imputation of 
missing data within a battery of variables, taking advantage of within-battery interrelationships. 
The second "i" in "iimpute" stands for "inflated" as, by default, imputed values are inflated by 
random perturbations that permit iimputed data for multiple contexts to substitute for multiply-imputed 
and duplicated datasets employed in Stata's {bf:{help mi:mi}} suite of commands.{p_end}
{p2col :{help gendummies:{ul:gendu}mmies}}generation of set(s) of dummy variables employing, as 
numeric suffixes to the names of variables in each set, the numeric values that {cmd:gendummies} 
actually finds in the data.{p_end}
{p2col :{help gendist:{ul:gendi}st}}(Context-wise) generation of distances between spatially-located 
self-placement variables and each member of a corresponding battery of spatial items, with customizable 
treatment of missing data.{p_end}
{p2col :{help genstacks:{ul:genst}acks}}(Context-wise) reshaping of a dataset for response-level 
analysis (see the relevant introductory paragraph above){p_end}
{p2col :{help genyhats:{ul:genyh}ats}}(Context-wise) generation of {it:y-hat} affinity measures that 
connect {help indepvars} to {help depvars}{p_end}
{p2col :{help gensummaries:{ul:gensu}mmaries}}generation of (optionally weighted) statistics for variables within contexts – similar to Stata's {help egen} command with the {bf:by} option, but permitting calculation 
of weighted statistics{p_end}{p2col :{help genplace:{ul:genpl}ace}}generation of (generally spatial) 
placements at the battery-level (e.g. legislature- or government-level of the battery items relate to 
political parties). Placements can optionally be weighted by the (weighted) number of respondents 
and/or by substantively meaningful weights (e.g. proportions of seats or of ministries controlled by 
parties that are members of a government).{break}{space 3}{cmd:genplace} also serves as an 
{bf:interface for user-written programs} that can ganerate additional or alternative variables that 
place battery items (or batteries as entities in themselves) in terms of user-specified concepts 
(e.g. polarization). An example of a user-written command is supplied, which generates 
{it:Issue Yield Index} values for battery items assumed to be political parties (De Sio and Webber 
2014). See help {help genwriteyourown:{ul:genWr}iteYourOwn} for details.{p_end}

{pstd}
The functionality of these tools can largely be emulated using existing Stata commands but those would in 
many instances require multiple steps (or call for advanced programing skills) in order to operate on data 
with multiple contexts (eg. countries or country-years), for each of which the data may need to be pre-processed, 
or otherwise manipulated, separately. Moreover, many of the commands in {cmd:StackMe} have additional 
features not readily duplicated with existing Stata commands, even for data that relate to a single context.

{pstd}
The commands take a variety of {help options}, as documented in individual help files, some with quite 
cumbersome names. However, all options can be abbreviated to their first three characters (except that 
negating an option, where allowed, requires the letters "no" to precede those three characters, resulting 
in five-character minimum abbreviations – the same length as applies to {cmd:stackMe} command abbreviations).
But most options have default settings that can be accepted by simply omitting the option (as documented).

{pstd}
The commands save a variety of indicators and measures, most of them being given {varname}s based on the 
names of the variable(s) from which they are derived (as documented). Three variables created by the command
{help genstacks:{ul:genst}acks} are needed by other {cmd:StackMe} commands and should not be deleted or have 
their names changed. These {help reserved variables} are {it:{cmd:SMstkid}} (the stack identifier), {it:{cmd:SMnstks}} 
(the largest number of stacks, some of which might be all-missing and thus completely absent in certain 
contexts) and {it:{cmd:SMunit}}, the sequential id enumerating all original observations over all contexts. 
Additionally, command {help genstacks:{ul:genst}acks} takes note of a user-defined {opt item name}, 
as an alternative stack identifier (if there is such) which it records in any dataset stacked by 
{help genstacks:{ul:genst}acks} under an additional reserved varname: {it:{cmd:SMitem}}. For details see 
below under the heading "Special names".

{marker Workflow}
{title:Workflow}

{pstd}
The {help genstacks:{ul:genst}acks} command normally operates on an unstacked dataset, {help reshape}ing it 
into stacked format (but it may also be used to "doubly-stack" an already stacked dataset). Other commands may 
operate on either stacked or unstacked data, except that {help genplace:{ul:genpl}ace} requires stacked data 
because the objects this command {it:place}s (in spatial terms) or {it:codes} (in terms of other attributes) 
consist of stacked batteries. No facility is provided for unstacking a previously stacked dataset (a crude 
way to do this would be to {help keep} just a single stack for every original observation). So it is strongly 
recommended that users create and save a dofile containing the Stata code responsible for prepping and 
stacking a Stata data file.{break}

{pstd}The commands {help gendist:{ul:gendi}st}, {help genyhats:{ul:genyh}ats} and {help genplace:{ul:genpl}ace} 
by default assume that the data are stacked ({help genplace:{ul:genpl}ace} {it:{cmd:requires}} that the data 
be stacked) and treats each stack as a separate context, to be taken into account along with any higher-level 
contexts. These commands (except for {cmdab:genpl:ace}) can, however, be used on unstacked data and/or they 
can be directed to ignore the stacked structure of the data by specifying the {opt nosta:ck} option. This 
option has no effect on {help gendummies:{ul:gendu}mmies} or {help gensummarize:{ul:gensu}mmarize} or on any 
{cmd:StackMe} command that is being used on unstacked data (since unstacked data only have one stack per unit). 
With stacked data, ignoring the separate contexts represented by each stack might make sense if exploratory 
analysis had established that there is no stack-specific heterogeneity relevant to the estimation model for 
which the data were being  pre-processed. Alternatively, the user might employ this option so as to 
{help geniimpute:{ul:genii}mpute} a variable that is completely missing in one or more stacks (e.g. particular 
choices asked only regarding a subset of parties).{break} 

{pstd}For logical reasons some restrictions apply to the order in which commands can be issued. 
In particular:{p_end} 
{pmore}(1) {help geniimpute:{ul:genii}mpute}, when used for its primary purpose of imputing (variance inflated) 
missing values for a battery of items, requires the data to {bf:not} be stacked, since members of that battery 
(eg. PTVs) are used to impute missing data for other members of the same battery; 

{pmore}(2) {help gendist:{ul:gendi}st} can be useful in plugging missing data for items that can then be named 
in {help geniimpute:{ul:genii}mpute}'s {opt add:vars} option to help in the imputation of missing data for other 
variables;

{pmore}(3) if {help gendist:{ul:gendi}st} is employed after stacking, the reference items from which distances 
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
commands except for {help genstacks:{ul:genst}acks} and {help genplace:{ul:genpl}ace} can be employed 
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
a colon, that preceeds the {varlist} of battery-members). This (set of) varlist(s) will generally be associated  
with an {it:{help option}}list, for example:{p_end}

{p 5 14}
{opt gendi:st} [{help varname:selfplace}:] {varlist} {bf:[if][in][weight]}{cmd:,} {it:{help options}} [ {bf:||}
[{help varname:selfplace}:] {help varlist} ... ]

{pstd}
The optionlist may appear anywhere among the varlist(s) but generally follows either the first or the last 
of them. The {bf:{help [if]} {help [in]} {help [weight]}} expressions that generally follow a Stata 
{varlist} can also be placed following any of the varlists but is generally placed following the first of them.

{pstd}
There can normally be only one single occurrence of "{bf:[if][in][weight], options}" for any {cmd:StackMe} 
command (but see {help stackme##Hiddengems:Hidden Gems}, below, for an exception).

{marker regardingversion2}
{title:Note regarding version 2.0}

{pstd}
This release of {cmd:StackMe} is actually Version 2 of what was originally named {cmd:PTVtools} 
(the acronym stands for Propensity To Vote – see Eijk et al 2006). It differs from {cmd:PTVtools} in having 
additional commands – {help gensummarize:{ul:gensu}mmarize}, {help genplace:{ul:gen}place} (which also provides 
an interface for user-written 
programs). {cmd:StackMe}’s user interface has been standardized across {cmd:StackMe} commands: pipe-delimited {varlist}s 
are available with all {cmd:StackMe} commands, not just with {cmd:genyhats}; all {cmd:StackMe} commands offer the 
same suite of options, invoked by the same option-names, to the extent that each option makes sense for the 
command concerned. The interface also provides additional functionality: [{help if}], [{help in}] and {p_end}
{pstd}
[{help weight}] can now be employed with all {cmd:StackMe} commands (except for {help genstacks}), not just 
{help gensummarize} and {help genplace}. More importantly, many {cmd:StackMe} commands run faster by an order of 
magnitude. This is especially true for {help genstacks}, {help geniimpute} and {help genyhats} (which are the 
commands most likely to involve all substantively relevant variables in a {cmd:StackMe} dataset).{break}{space 3}
Initially we are distributing a beta version of {cmd:StackMe} 2.0, which may still contain bugs and infelicities. 
Any comments and/or suggestions for improvements should be emailed to mark.franklin@trincoll.edu (if no response 
within a week, email the first author named below).{break}

{marker stackmespecialnames}
{title:stackMe special names}

{pstd}
Four "special names" are employed by {cmd:stackMe}. These names should be avoided when picking names for 
substantive variables within a dataset that will be processed by {cmd:stackMe}. Three of these are variable 
names reserved for variables added to datasets that have been reshaped by the {cmdab:genst:acks} command. 
A fourth "special name" modifies the data label of a stacked dataset to flag the fact that the data have 
been stacked. These names are as follows:{p_end}

{p 4 10} 
{bf:SMunit} The {it:observation number} (or 'i' variable described in Stata's {help reshape} command. This variable 
is identical to the value of the Stata system variable {help _n} when not associated with {help by}). In survey 
research each observation will generally have been given a {it:respondent id number} that might be identical to 
{it:{cmd:SMunit}} but the presence or absence of such a respondent ID is ignored and unaffected by {cmd:stackMe} 
commands (unless that variable should be the one named in the string data held by {it:{cmd:SMitem}} (see below).{p_end}

{p 4 10} 
{bf:SMstkid} The {it:stack identifier} (or 'j' variable described in Stata's {help reshape} command) identifies 
each of what were members of a battery of number-suffixed stub-names. If those suffixes were sequential numbers 
starting with '1' for the first suffix, values of SMstkid will match the original suffix-values.{p_end}

{p 4 10}
{bf:SMnstks} The {it:number of stacks}, constant across units and identical to the value of the Stata system 
variable {help _N} when not associated with {help by}.{p_end}

{p 4 10}
{bf:STKD} These four letters, plus a space to delimit the end of the word, are tacked on to the front of the data 
label of any dataset that is reshaped using {cmdab:genst:acks}. The original label that, in Stata, is limited to 
80 characters in total length is then stripped of its final five characters (if present) and the new label becomes 
the label of the stacked file, displayed every time the file is "use"d. The original label, including its final 
five characters (if present), can be placed in a global by typing: 'global origlabel : char _dta[label]' (or you 
can employ any other name you like for the global). If you use that name you can see the global's contents by typing 
'display "$origlabel"'. If the original file had no data label then a new label is created which consists of the 
letters "STKD " followed by the words "by stackMe's command genstacks". You can change this to a more substantively 
meaningful label using Stata's {help label data} command, but you should ensure that any new label also starts with 
the letters "STKD" followed by a space.{p_end}

{p 4 10}
{bf:NOTE:} Additional variables are added by command {help genstacks} when producing doubly-stacked data. The ID 
variable {it:{cmd:SMstkid}}} (and its doubly-stacked equivalent) can by overriden by use of the {opt ite:mname} 
option provided by relevant {cmd:stackMe} commands.


{marker Authors}
{title:Authors}

{pstd}
Lorenzo De Sio - European University Institute (now at LUISS): ldesio@luiss.it{break}
Mark Franklin - European University Institute (now emeritus at Trinity College Connecticut):mark.franklin@trincoll.edu


{title:Citations}

{pstd}
If you employ {bf:StackMe} in published work, please use the following citation:{break}
De Sio, L. and Franklin, M. (2011) "StackMe: A Stata package for analysis of multi-level data" 
(version 2.0), {it:Statistical Software Components}, Boston College Department of Economics.

{pstd}
To better understand generic variable analysis in a comparative framework see:{break}
Eijk, C. van der, Brug, W. van der, Kroh, M. and Franklin, M. (2006) "Rethinking the dependent variable in voting 
behavior: On the measurement and analysis of electoral utilities", {it:Electoral Studies} 25(3): 424-447.{p_end}
