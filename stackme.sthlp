*! Oct 22'26
{smcl}
{cmd:help StackMe}
{hline}

{p2colset 3 14 14 2}{...}
{p2col :{bf:StackMe} {hline 2}}package of Stata commands that pre-process and {help reshape} data in 
preparation for multi-level or hierarchical (sometimes known as contextual) analysis, often of survey 
data;  also providing an interface to other Stata commands that can be used to analyze the resulting 
data with the benefit of {bf:stachMe}'s contextual awareness. Use View->Viewer->Refresh to adjust window size -->|  
   (This helpfile contains diagrams that can lose coherence if lines are shorter).{p_end}

{p2colreset}{...}

{marker Introduction}
{title:Introduction}

{pstd}
The {cmd:stackMe} package is a collection of software tools for generating and manipulating stacked 
{help reshape:(reshape}d) data. In the academic subfield of electoral studies, where StackMe was 
developed, reshaping is commonly employed to facilitate the analysis of multi-level (hierarchical)
survey data (see below). Indeed, use of {cmd:stackMe} is hardly called for with conventional survey 
data. The {bf:stackMe} package adds transparency to operations involving hierarchical data of any 
kind; also helping the user to keep track of the plethora of variables needed to make the most of 
hierarchical analyses as well as significantly accelerating (by at least an order of magnitude) the 
generation of such variables in what are often very large datasets.{p_end}

{marker Quickstart}
{title:Quick Start}

{pstd}
This help file is quite verbose, aiming to provide an introduction to the operationalization of what, 
to some, may seem quite esoteric concepts using what, to others, might be somewhat impenetrable 
vocabulary (perhaps deriving from a different research tradition). If you already know what is meant 
by phrases like "question battery", "reshaping"/"stacking" "generic variable" and "affinity measure" 
you may want to dive right into the {bf:stackMe} commands that facilitate the creation/manipulation 
of such batteries and measures, using links provided in those commands' help files to clarify matters 
that remain obscure. This short paragraph introduces the one command needed to get started.{p_end}
{marker SMsetconts}{...}
{pstd}{space 3}The {bf:stackMe} utility {help stackme##SMsetcontexts:{ul:SMset}contexts} provides other 
{bf:stackMe} commands with the most fundamental information regarding the dataset currently in 
{bf:{help use}}: the names of variables (often {it:country} and {it:year}) that define its hierarchical 
structure (if any), thus:{p_end}

{pstd}{space 3}{cmdab:SMset:contexts} [ {varlist} ] [ , nocontexts ]{p_end}

{pstd}It is recommended that this utility be invoked immediately after {bf:{help use}}ing the datafile that 
will be processed by other {bf:stackMe} commands.{p_end}  
{pstd}Those other {bf:stackMe} commands are listed and briefly introduced in the {help stackme##Description:Description} 
section of this introductory helpfile. But first, for those taking the more leisurely approach, we need to 
introduce some foundational concepts and vocabulary.

{marker Datastacking}
{title:Data Stacking}

{pstd}
This often involves what are referred to as "batteries" of survey items, each of which asks 
the same survey question about each in turn of a number of conceptually-connected 
reference-items, often political parties. Each respondent to the survey provides a set of answers 
to each battery of questions, producing a corresponding battery of variables in the resulting 
dataset. If the same questions were asked about four political parties there would be four 
responses in each battery at the respondent level of analysis. This way of organizing 
the data is referred to by Stata as {help reshape:"wide"} format, as illustrated. 

              Wide     
    +-------------------------+         Wide-format layout of data regarding left-right positions 
    |  i  plr1 plr2 plr3 plr4 |         (plr) of four parties, identified by numeric suffixes 1-4 
    |-------------------------|         appended to the 'plr' stubs, for two respondents numbered 
    |  1   4.1  4.5  6.5 5.4  |         i=1 and i=2. And we see each of the four left-right party 
    |  2   3.3  3.0  4.4 4.0  |	        positions observed by each respondent as being "stacked",
    +-------------------------+         with i=1 responses positioned above the i=2 ones.

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
    | 1  2  4.5 |         substantive variables are now assigned to successive observations for the 
    | 1  3  6.5 |         one long-format substantive variable.
    | 1  4  5.4 |            Thinking of the four {bf:{it:plr}} columns in wide format as themselves being stacks 
    | 2  1  3.3 |         of observations, we might see the long-format {bf:{it:plr}} variable as being a sort 
    | 2  2  3.0 |         of "superstack" in which the wide-format {bf:{it:plr}}# variables have been interleaved
    | 2  3  4.4 |         across individual respondents identified by different i-values. In this 
    | 2  4  4.0 |         "stack of stacks" each j-value identifies the wide-format stack that had 
    +–––––––––––+         previously housed that same observation (why 'j' is called a "stack id").
                          
{pstd}
And note that the data-point concerned (for example the value 4.0, bottom right of each table) can be 
correctly called an "observation" in either format. The difference lies in who is making the observation 
– the reseacher who posed the question or the respondent who answered it. In wide format the focus is on 
the respondent and features of that respondent (in survey research, often the opinions of that respondent 
including their opinions regarding political parties, in our example). In long format the focus is on the 
items that respondents were asked about and features of those items (in the opinion of each respondent). But 
the survey is likely to ask about many topics beyond the battery items that will be stacked: features of 
the respondent, such as their age, gender, and level of education; and features of the situation in which 
respondents find themselves (such as the state of the economy). Such features do not vary across the
items being stacked (political parties in our example) so, if such variables are included in the reshaping 
operation that stacks the data, they will be constant across the observations relating to each party for 
each respondent. But, even if constant across battery items, those variables may still affect relationships 
between respondents and battery items (in a bad economy respondents may support different parties than they 
would in a good economy).

{pstd}
{bf:IT IS IMPORTANT} to keep track of whether a dataset is stacked or not and, if stacked, what is the 
"stack identification variable". In datasets stacked by {cmd:stackMe}'s {help genstacks:{ul:genst}acks} 
command, this variable is named {it:{cmd:SMstkid}} by default and it is recommended that this name not be 
changed. This variable, the `j' variable in the above description of stacked data, generally identifies 
the battery item that corresponds to each stack but, if it does not, then a variable must be created (if it 
does not already exist) that links stacks to batteries (for example, party identification number). It is 
recommended that such links between stack IDs and battery items be named by {cmdab:genst:acks}'s {opt ite:mname()} 
option. The variable concerned will be added to the list of variables to be reshaped by {cmdab:genst:acks} 
so that the stacked counterpart can be used to define relevant linkages (for example when merging the stacked 
data with data from relevant archives). For a more detailed account of these linkage mechanisms see the 
{help stackme##stackmespecialnames:Special Names} section of this help text, below, and the help text for stackMe 
command {help genstacks:{ul:genst}acks}.{p_end} 
{pstd}
Data stacking is often employed in statistical analyses involving hierarchical or multi-level 
(sometimes known as contextual) data, as already mentioned. Indeed, {cmdab:genst:acks} is mainly 
useful in such contexts. With a conventional dataset from a single context, the standard Stata 
{help reshape} command would be just as appropriate and (possibly) a tad faster. For a more detailed 
walk-through of the logic of data-stacking see the {cmd:stackMe} help file named {help SMwriteYourOwn}.{p_end}

{pstd}
{bf:CRITICAL NOTE:} A dataset can only be stacked on the basis of one variable (a second variable 
can be added for doubly-stacked data). So a conventional dataset that contains batteries of variables 
organized in regard to more than one set of items (say batteries that ask the same questions about each 
issue as well as batteries that ask about each party) can give rise to more than one stacked dataset: 
in this example, one stacked by party and a different one stacked by issue. Either of these stacked 
datasets could later be doubly-stacked with parties within issues (or issues within parties).{p_end}

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
stacked. Batteries that have different lengths (e.g. different numbers of political parties) in 
different contexts imply missing data for all observations in certain of those contexts.{p_end}
{pstd}
{space 3} {bf:Empty batteries:} In conventional comparative survey data (e.g. the European Social 
Survey or  surveys post-processed by the Comparative Study of Electoral Systems) a fair number of 
question batteries are largely empty so as to accommodate data from countries whose surveys had 
larger numbers of battery items (e.g. political parties). After reshaping, such surveys produce 
many observations that are entirely missing for all but respondents from a single (or a very few) 
countries. StackMe, by default, avoids burdoning execution time with evaluations of rows that consist 
entirely of missing data due to such happenstances.{break}
{space 3} {bf:Battery boundaries} also have a number of implications relevant to the handling of 
{it:hierarchical data}. These arise because batteries of variables often have interrelationships 
(typically negative inter-correlations due to patterns in respondent preferences – for example 
preferences for political parties). Such patterns can affect multivariate analyses of any kind. 
For example, multivariate analyses are at the heart of imputation estimations which may be 
deliberately performed using unstacked data in order to take advantage of within-battery 
interrelationships when plugging observations for which answers to battery questions are absent.{break}
{space 3} {bf:Units and items} The malleability of data in terms of wide versus long format gives 
rise to ambiguity when referring to "observations", a word that changes its meaning with changes 
in the level of analysis. In {cmd:stackMe} we use the word "unit" to refer specifically to 
observations at the original level of analysis, before stacking, and the word "item" to refer 
specifically to the battery item that will become an observation after stacking.{p_end}

{marker Genericvariable}{marker Affinitymeasures}
{title:Generic variable analysis and affinity measures}

{pstd}
Critically, the dependent (outcome) variable is usually generalized to accommodate multiple contexts. 
So while in electoral studies conducted in one country a scholar might seek to answer a research 
question such as "why do people vote for the Liberal party?", with multiple countries having different 
party systems that question will generally need to be reconceptualized in terms of votes for a 
{it:generic} party – {it:any} party – with a research question like "what explains the level of electoral 
support that a party receives?" (Thus "voting for party A" becomes "voting for a party") Such 
reconceptualization involves moving up the ladder of conceptual generality, which also happens when 
"Sun-Times" is viewed as a "newspaper" or "Lincoln High" is viewed as a "school". Such reconceptualizations 
produce comparability across contexts if these involve different party systems or media structures or 
educational systems, as is common. More importantly, the more general conceptualization inevitably results 
in more generally applicable explanations of social phenomena – what many would say is the primary benefit 
of comparative socio-political studies. But these more general explanations also require a more generic 
formulation of {it:independent} variables (more generally referred to {it:input} variables – a more 
appropriate terminology when dealing with variables to be pre-processed without regard to their statistical 
status). Such variables must be reformulated to focus on the process or mechanism that brings the two 
together, often referred to as the "affinity" that an indep shows for a depvar (or {it:vice-versa}).

    +–––––––––––––––––––––––––––+         {bf:Deriving proximity as a measure of affinity} between
    | i  j  plr  rlr  dlr  prox |         voters and parties in left-right terms. Variable plr
    |–––––––––––––––––––––––––––|         is the same variable used earlier; rlr is respondent's
    | 1  1  4.1  2.2  1.9  8.1  |         left-right position; dlr is the distance between rlr 
    | 1  2  4.5  2.2  2.4  7.6  |         and plr on a 10-point scale. Proximity, the final 
    | 2  1  3.3  6.5  2.3  7.5. |         variable, is inverse distance (10 - dlr), a measure of 
    | 2  2  3.0  6.5  4.2  5.8. |         affinity between voters and parties in left-right terms.
    +–––––––––––––––––––––––––––+

{pstd}
{cmd:StackMe} has separate commands that generate three alternative measures of affinity: proximities – 
inverted distances as shown above (see the help text for the {bf:stackMe} command {help gendist:{ul:gendi}st}) 
– and, for non-spatial items, either dummy variables (e.g. "the party this respondent voted for", "the party 
this responded feels close to" – see command {help gendummies:{ul:gendu}mmmies}) or so-called {it:y-hat}s 
(see command {help genyhats:{ul:genyh}ats}). Easing the construction of such affinity measures was originally 
intended to encourage research employing PTV (for Propensity To Vote) measures, derived from survey data, as 
a substitute for discrete choice modeling that involved analysis of choices made (van der Eijk et al., 2006). 
But analysis of discrete choice data can benefit just as much from many of the facilities that {cmd:StackMe} 
provides.{break}
{space 3}A primary objective of {cmd:StackMe}'s {help genplace:{ul:genpl}ace} command is to provide links 
to other {bf:Stata} commands, such as {help factor} and {help MCA}, that already generate the functional 
equivalent of affinity measures (see, e.g., Weber and Franklin 2018). Those {cmdab:genpl:ace} linkage 
facilities also permit user-written contributions to {bf:stackMe} of pretty much any kind, one of which is 
a demonstration program that further increases the number of ways in which affinities can be measured. For 
more about adding user-written programs to {cmd:stackMe} see the help texts for {help genplace:{ul:genpl}ace} 
and {help SMwriteyourown:{ul:SMwri}teYourOwn}.{p_end}

{pstd}
Most of the above affinity measures bring with them limitations often linked with some degree of controversy 
regarding their theoretical or methodologica underpinnings. But {help stackme##gendummies:{cmdab:gendu:mmies}} 
engenders no controversy and its major limitation (the fact that a numerical variable will have to be divided 
into categories of increasing magnitude) is well-understood and non-controversial. It is a "lowest common 
denominator" fallback for operationalizing an affinity measure based on any sort of data; also for operationalizing 
what we will refer to as "dual-affinities" in doubly-stacked data. See {help SMwriteyourown:{ul:SMwri}teYourOwn} 
for more on this topic.{p_end}
{pstd}{space 3}The non-controversial nature of dummy variable affinities is linked to the fact that no measurement 
model underlies their generation: each dummy variable simply represents one category taken from a categorical 
variable. So long as all categories are represented in this fashion, the information contained in a battery of 
dummies is identical to the information contained in the categorical variable from which those dummies were 
derived. Strictly speaking, no pre-processing was involved (reason why {cmdab:gendu:mmies} outcome variables are 
not provided with prefix strings, except in special circumstances.{p_end}

{marker Doublystackeddata}
{title:Doubly-stacked data}

{pstd}
This type of data structure is relevant to the analysis of hierarchical (multi-level) data in any 
discipline; but we introduce the concept with benefit of an example from our own subfield. In 
electoral studies, as well as batteries of party-related questions, there can also be batteries 
of issue-related questions. Issues are of relevance not only to respondents (who often have issue 
preferences that vary across issues) but also to parties (that often take different positions in 
regard to different issues). Issue batteries can be stacked either within parties or within respondents; 
but if they are stacked within parties that are already stacked within respondents then the data 
become doubly-stacked and the stacking of issues within parties within respondents can be used 
to link parties to respondents via the issues that both have in common, facilitating studies 
of issue-based party choice.{p_end}
{pstd}{space 3}In principle it would be possible to construct triply-stacked, and datasets with even greater 
dimensionality, but such datasets can become colossal in size and utterly unwieldy to manipulate. We advise 
users to employ, as a more tractable alternative, {help SMwriteYourOwn##subordinatebatteries:subordinate} 
batteries, as described in the helpfile named {help SMwriteYourOwn}.

{marker Affinitymeasures}
{title:Affinity measures in doubly-stacked data}

{pstd}
There are no established procedures for handling affinities in doubly-stacked data, so anyone wanting 
to attack this frontier of research in their own academic discipline is free to design their own approach, 
perhaps helped by the examples provided of our own approach to doubly-stacked data in the subfield of 
electoral studies. As already mentioned, these examples take the form of "user-written programs" that 
can be "hung" onto "hooks" that we have provided, in {cmd:StackMe}'s {help genplace:{ul:genpl}ace} 
command, designed to facilitate the incorporation into {cmd:stackMe} of new code that operationalizes 
whatever new insights may arise. See the help texts for {help SMwriteyourown:{ul:SMwri}teYourOwn} for 
details. That helpfile also introduces alternatives to double-stacking a dataset that contains what 
we there refer to as "subordinate batteries"; and presents the most straightforward means for analysing 
doubly-stacked data by employing dummy variables ({help stackMe##gendummies:indicator variables}).{p_end}

{marker Programefficiency}
{title:Program efficiency}

{pstd}
Multi-level comparative datasets constructed from survey data across multiple countries over 
increasingly lengthy spans of time can be huge. Standard data analysis procedures with such data 
can be very time-consuming. For one-off estimation analyses those costs must be born, but for 
data management tasks that will be repeated multiple times it is worth taking the trouble to come 
up with (and learn to benefit from) procedures that maximize Stata's strengths, even at the cost 
of heavy outlays of time for program-design and coding. Such programming efforts give rise to 
suites of Stata commands such as the package documented here. {cmd:StackMe} has been operationalized 
on the basis of extensive experimentation to minimizing processing time especially for operations 
that will need to be repeated for a large proportion of variables in a survey-based dataset. The 
syntax innovations adopted for {cmd:StackMe} commands are designed to facilite the processing of 
as many variables as possible on a single pass through the data, permitting programming strategies 
that minimize execution time. Details can be found under {help stackme##prefixes:syntax innovations}, 
below.{p_end}

{marker Description}
{title:Description}

{pstd}
The {cmd:stackMe} package includes the following commands, all of which can be abbreviated to their 
first five characters (but longer abbreviations are not allowed):

{p2colset 5 17 15 2}{...}
{p2col:{ul:Commands primarily intended to prepare data for stacking}}{p_end}

{p2col :{help stackme##SMsetcontexts:{ul:SMset}contexts}} establishes, within the datafile currently in 
{help use}, a 'data characteristic' for the benefit of other {bf:stackMe} commands that either identifies 
the dataset as a standard Stata .dta file, without distinctions between contexts, or provides a 
list of the variables that will define that dataset's contexts (e.g. {it:country} and {it:year}). The data 
in the file should not already be in stacked format (what Stata calls "long format") when its contextvars 
are defined.{p_end}
{marker gendummies}
{p2col :{help gendummies:{ul:gendu}mmies}}generates batteries of dummy variables, each battery encompassing the values 
(Stata sometimes refers to these as "levels") of a categorical variable whose name, by default, becomes the textual 
stub for the name of each outcome dummy in the battery. These outcomes can be seen as equivalent to batteries of 
{help factor variables} (Stata sometimes refers to these as indicator variables or virtual variables) that take the 
value 1 for observations with the value indicated by the suffix to that indicator and zero otherwise. So when 
{cmdab:gendu:mmies} names as input a categorical variable called {it:gender}, taking on values of 0 for males and 1 for 
females, the resulting battery of outcomes will hold two dummy variables named {it:gender0} and {it:gender1} for which 
each each observation will be coded 1 if that observation has the input value of the suffix and 0 otherwise. This is 
In contrast to Stata's {help tabulate1} command (with the {opt generate} option) that would produce two outcomes named 
{it:gender1} and {it:gender2} whatever two values were found in the data. And, unlike Stata's {help factor} variables, 
these dummy variables will actually exist in the dataset, once defined, making them amenable to stacking (which factor 
variables are not). See the {help gendummies:{bf:{ul:gendu}mmies}} helpfile for details.{p_end}
{p2col :{help geniimpute:{ul:genii}mpute}}(Context-wise) incremental simple or multiple imputation of missing 
data within a set of variables, taking advantage of within-set interrelationships if the data are not yet stacked 
(see {help geniimpute:{bf:{ul:genii}mute}} for details). The second "i" in "iimpute" stands for "inflated" as, by 
default, imputed values are inflated using random perturbations that produce iimputed data for multiple contexts 
that are conceptually equivalent to multiply-imputed datasets as employed by Stata's {bf:{help mi:mi}} suite of 
commands – data for which the "mutiple" in "multiply-imputed" is obtained by duplicating the original observations 
as many times as needed while adding random perturbations to observations whose missing data have been plugged  
(c.f. King et al. 2001).{p_end}
{p2col :{help gendist:{ul:gendi}st}}(Context-wise) generation of distances between spatially-located self-placement 
variables and each member of a corresponding battery of spatial items (e.g. political parties), with customizable 
treatment of missing data. It makes no difference to the results whether this command is issued before or after 
stacking.{p_end}
{p2col :{help genyhats:{ul:genyh}ats}}(Context-wise) generation of {it:y-hat} {help stackme##Genericvariable:affinity} 
measures that can facilitate {help genstacks##Genericvariable:generic} variable analysis in stacked data. Such 
variables can be generated either before or after stacking. But, for both {help gendist:{ul:gendi}st} and 
{help genyhats:{ul:genyh}ats}, it will generally be more economical to generate the resulting measures after stacking. 
However, the order in which these two commands are employed (in relation to each other and in relation to command 
{help genstacks:{ul:genst}acks}) could matter in ways that, to the best of our knowledge, have not yet been fully 
investigated. See under the heading {help stackme##Workflow:Workflow}, below, for some relevant considerations).{p_end}

{p2col:{ul:Stacking command}}{p_end}

{p2col :{help genstacks:{ul:genst}acks}}(Context-specific) reshaping of a dataset for response-level 
analysis (see the relevant introductory {help stackme##Datastacking:paragraph} above). No facility is 
provided for unstacking a previously stacked dataset (a crude way to do this would be to {help keep} 
just a single stack for every original observation). So it is strongly recommended that users create 
and save a dofile containing the Stata code responsible for prepping and stacking the original Stata 
data file. ({bf:NOTE} that the original data file may give rise to more than one stacked dataset (or 
to {help stackme##Doublystacked:doubly-stacked} data) if the original dataset contains question batteries 
relating to more than one set of reference items – for example batteries related to issues (one question 
per battery for each issue) as well as batteries related to parties (one question per battery for each 
party).{p_end}

{p2col:{ul:Commands primarily intended for use with stacked data}}{p_end}

{p2col :{help SMitemnames:{ul:SMite}mnames}} names, within the datafile currently in {help use}, 
two more 'data characteristics' (complementary to the 'contextvars' characteristic documented at the 
top of this list of {cmd:stackMe} commands). These can (re-)define the linkage variables (named 
{it:{bf:SMitem}} and {it:{bf:S2item}}) described in {help stackme##stackmespecialnames:Special Names} 
later in this helpfile. Those SM names serve as aliases to variables that can supplement {it:{bf:SMstkid}} 
and {it:{bf:S2stkid}} in identifying the different stacks created by {help genstacks:{ul:genst}acks}.{p_end}
{p2col :{help SMfilename:{ul:SMfil}ename}}{...} corrects the name of the datafile currently in use, if that 
name somehow no longer matches the actual name of that file. Generally these names are updated automatically 
as a file morphs from original to stacked to {help stackme##Doublystacked:doubly-stacked} status (or 
as users rename or move a file to a different directory within the computer's file structure); but things 
can go wrong and this utility program would be used to fix any filename glitches.{p_end}
{p2col :{help SMorigin:{ul:SMori}gin}}{...} provides a list of variables each of whose labels is to be 
individually elaborated into an "origin story" naming the variables that were its precursors as it was 
processed successively by, for example, {opt genii:mpute} -> {opt gendi:st} -> {opt genyh:ats}. Note that 
{cmd:stackMe}-generated variables already receive labels that record the operation producing each new 
outcome. A {help SMorigin:{ul:SMori}gin}-generated label simply elaborates each of these descriptions into 
a summary historical record (losing some detail in the process).{p_end}
{p2col :{help genmeanstats:{ul:genme}anstats}}generates (optionally weighted) variable means, 
and other mean-related statistics, separately within contexts – similar to Stata's {help egen} command 
with the {bf:by} option but permitting the statistics to be appropriately weighted, which the above 
alternative does not. Command {help genmeanstats:{ul:genme}anstats} can optionally be 'call'ed from within 
command {cmdab: genpl:ace} (below) if objects are to be placed on grounds other than mean values.{p_end}
{p2col :{help genplace:{ul:genpl}ace}}generates placements at the battery-level that will characterize 
battery items in terms of unit-level characteristics (placing e.g. political parties in terms of the 
characteristics of respondents who vote for those parties). At a higher level {cmdab:genpl:ace} can place 
higher-level objects, such as governments, in terms of battery-level characteristics (for instance 
locations in left-right terms of the parties that are members of a government). Placements can optionally 
be weighted by the (weighted) number of respondents and/or by substantively meaningful weights (e.g. 
proportions of seats or of ministries controlled by parties that are members of a government).{p_end}
{p2col :{help genxlvlags:{ul:genxv}lags}}inserts into respondent-level repeat cross-section survey data (or 
other lowest level of a TSCS dataset) lagged versions of listed variables measured at that level (what 
we will refer to as "source-variables"), where the lagged versions are generated at the lowest superior level 
at which Stata's lagging/differencing variable prefixes can sensibly be employed (what we will refer to as 
the "lagging level"). The resulting lagged/differenced variables each takes the form of a mean value 
averaged across respondents. These are then merged back into the source-level data and the resulting 
variables (constant across respondent within lagging level ID) will each then have their variance inflated 
to match the variance of the corresponding source variable at the appropriate time-point. The resulting 
lagged source-level variables can appropriately be used in TSCS survey data of a suitable kind. See {help 
genxlvlags:{ul:genxv}lags}} for details.

{pstd}{cmdab:genpl:ace} (two commands up) also serves as an {it:interface} for existing Stata or user-written commands that can generate additional or alternative variables for placing battery items (or batteries seen as 
concepts/entities in themselves). Thus {help factor} or {help MCA} analysis can generate scores that are 
distiguished by context, and affinity measures can be constructed from the results of context-dependent 
transformations and estimation procedures. Two examples of user-written commands are supplied that focus 
on the second of these objectives. One of them calculates a {it:polarisation} measure for stacked 
parties; the other generates {it:Issue Yield Index} values for battery items such as political parties 
(De Sio and Webber 2014). See help {help SMwriteYourOwn} for details. User programs are not limited to 
those that 'place' higher-level variables in terms of lower-level characteristics but may perform any 
sort of transformation or analysis that involves the variables listed in a {cmdab:genpl:ace} command (which 
can also hold the user-chosen options modifying the command in question). See {help genplace:{ul:genpl}ace} 
and the helpfile named {help SMwriteYourOwn} for details.{p_end}

{pstd}
The functionality of these tools can largely be emulated using existing Stata commands but this would in 
many instances require multiple steps (or call for advanced programing skills) in order to operate on data 
with multiple contexts (eg. countries or country-years), for each of which the data may need to be separately 
pre-processed or otherwise manipulated. Moreover, many of the commands in {cmd:StackMe} have additional 
features – especially speed of execution – not readily emulated when using existing Stata commands.{p_end}

{pstd}
The commands take a variety of {help options}, as documented in individual help files, some with quite 
cumbersome names. However, all options can be abbreviated to their first three characters (except that 
negating an option, where allowed, may require the letters "no" to precede the three characters concerned, resulting in five-character minimum abbreviations – the same length as applies to {cmd:stackMe} command-name 
abbreviations). But most options have default settings that can be accepted by simply omitting the option (as documented).{p_end}

{pstd}
The commands save a variety of indicators and measures, most of them being given {varname}s based on the 
names of the variable(s) from which they are derived (as documented). Three variables created by the command
{help genstacks:{ul:genst}acks} are needed by other {cmd:StackMe} commands and should not be deleted or have 
their names changed. These {help special names} are {it:{cmd:SMstkid}} (the stack identifier), {it:{cmd:SMnstks}} 
(the largest number of stacks, some of which might be all-missing and thus completely absent in certain 
contexts) and {it:{cmd:SMunit}}, the sequential id enumerating all original observations over all contexts. 
Additionally, command {help genstacks:{ul:genst}acks} takes note of a user-defined {cmd:item name}, 
as an alternative stack identifier (if there is such) which it records in any dataset stacked by 
{help genstacks:{ul:genst}acks} under an additional special varname: {it:{cmd:SMitem}}. For details see 
below under the heading {help stackme##stackmespecialnames:Special names}.

{marker Workflow}
{title:Workflow}

{pstd}
The {help genstacks:{ul:genst}acks} command normally operates on an unstacked dataset, {help reshape}ing it into 
long format (but it may also be used to {help stackme##Doublystackeddata:doubly-stack} an already stacked dataset.
Other commands may operate on either stacked or unstacked data, except that command {help genplace:{ul:genpl}ace} 
requires stacked data because the objects this command {it:place}s (in spatial terms) or {it:codes} (in terms of 
other attributes) consist of stacked batteries.{break}

{pstd}Although having design features that separate commands into the three categories distinguished above, all 
commands in the first list may be used with either stacked or unstacked data. But command {help genplace:{ul:genpl}ace} 
makes no sense with unstacked data; and command {help genmeans:{ul:genme}anstats} has very limited functionality in 
datasets that have not been stacked. Other commands, when used with stacked data, can be directed to ignore the stacked 
structure of the data and/or its contextual specificity by employing the {opt nosta:cks} and/or {opt nocon:texts} 
options, although these options have no effect on {help gendummies:{ul:gendu}mmies} which always operates at the level 
of analysis at which its {varlist} variables were defined or generated.{break}

{pstd}With stacked data, ignoring the separate contexts represented by each stack might make sense if exploratory 
analyses had faileds to find significant stack-specific heterogeneity relevant to the estimation models 
for which the data are being pre-processed. Alternatively, the user might employ the {opt nosta:cks} option so as to 
{help geniimpute:{ul:genii}mpute} plugging values for a variable that is completely missing in one or more stacks 
(e.g. resulting from particular alternatives that were not asked about for certain parties). The same considerations 
might justify the use of the {opt nocon:text} option in appropriate circumstances.{break}

{pstd}For logical reasons some restrictions apply to the order in which commands can be issued. In particular:{p_end} 
{pmore}(1) {help geniimpute:{ul:genii}mpute}, when used for its primary purpose of imputing (variance-inflated) 
plugging values (that will replace values that are missing in a battery of items) requires the data to {bf:not} be 
stacked, since items in each battery (e.g. party placements) are used to impute missing data for other members of the 
same battery while taking advantage of the negative correlations expected between members of the same battery; 

{pmore}(2) {help gendist:{ul:gendi}st} can be useful for plugging missing data for items that can then be named 
in {help geniimpute:{ul:genii}mpute}'s {opt add:vars} option to help in the imputation of missing data for other 
variables;

{pmore}(3) if {help gendist:{ul:gendi}st} is employed after stacking, the reference items from which distances 
are generated have themselves to have first been {help reshape}d into long format by including them among the 
variables to be stacked; and, finally,

{pmore}
(4) After stacking and the generation of y-hat affinity variables, the number of variables required for 
a final (set of) {help geniimpute:{ul:genii}mpute} command(s) will generally be greatly reduced, cutting the time 
needed to perform missing data imputations for what are often very large datasets.

{pmore}{bf:NOTE that processing time can be greatly reduced by grouping together all (pipe-delimited) {varlist}}s 
that can be processed by a single stackMe command under control of a single set of {it:{help options}}. This is a 
general feature of {cmd:StackMe} commands (see below under {help stackme##Variablelists:Variable lists}) although 
the effect is most evident with {help geniimpute:{ul:genii}mpute} and {help genyhats:{ul:genyh}ats} – the two 
{cmd:StackMe} commands that make greatest demands on processing power because they are generally employed to 
pre-process such a large proportion of the variables in a stacked dataset. (The {help genstacks:{ul:genst}acks} 
command has also been greatly accellerated, but using a different programing strategy.){p_end}

{pstd}
Consequently, a typical workflow would begin by using {help gendist:{ul:gendi}st} to (optionally) plug missing values 
on item location variables and generate distance measures (each of which replaces its two constituent position measures 
by a single distance of proximity measure), followed by {help geniimpute:{ul:genii}mpute} to fill out remaining missing 
data in batteries of conceptually-linked items by plugging their missing values, and {help genyhats:{ul:genyh}ats} to 
transform indeps (those not already rendered tractable by being transformed into dummy variables or distance measures) 
into y-hat {help stackme##Affinitymeasures:affinities} with the stacked depvar. Then command {help genstacks:{ul:genst}acks} 
would be used to {help reshape} the data. The results might then be used in a final {help geniimpute:{ul:genii}mpute} 
(with multiple {varlist}s) operation to cull remaining missing data (Stata's {help mi:{bf:mi}} command(s) might be viewed 
as alternatives). See the section on {help geniimpute##Multipleimputation:Multiple Imputation} in the help file for 
{cmdab:genii:mpute}.{p_end}
{pstd}
{space 3}Considerable flexibility is available to transform a dataset in any sequence thought appropriate, since any commands 
except for {help genstacks:{ul:genst}acks} and {help genplace:{ul:genpl}ace} can be employed either before or after 
stacking ({help genstacks:{ul:genst}acks} can itself be used to {help stackme##Doublystacked:doubly-stack} an already 
stacked dataset). Moreover, the researcher can use the {opt nos:tacks} and {opt noc:ontexts} options to force the 
production of distances, y-hats and missing data imputations that "average out" contextual differences by regarding 
all stacks (and perhaps also certain higher-level contexts) as a single context. This might make sense after preliminary 
analyses had established that there were no significant differences between these contexts in terms of the behavior of 
variables to be included in an estimation model.{p_end}

{pstd}
{bf:IMPORTANT NOTE ON KEEPING TRACK OF CONTEXTUAL DIFFERENCES} While country-year contexts are often collapsed into 
year contexts for (cross-section) time-series analyses and this might call for a (temporary) {opt con:textvars} option 
on a relevant {cmdab:genii:mpute} command (possibly for other {cmd:stackMe} commands as well), this sort of implicit 
collapsing of contextual differences should generally not be optioned in a {cmdab:stackme} command. Users can use the 
Stata {help collapse} command, after {help preserve}ng the pre-processed data, in time for specific Stata estimation 
commands. For these, panel variables can be specified as needed for relevant estimation commands (such as Stata's 
{help xt} commands or {help mixed} command) without affecting the underlying data. The pre-processed data can 
then be {help restore}d and employed to estimate other models without re-stacking.{break}
{space 3}{bf:USER BEWARE:} most {cmd:stackeMe} commands themselves {help preserve} the data for each context in turn 
and thus cannot be employed on data that the user has previously {help preserve}d.{p_end}

{marker Variablenaming}
{title:Variable naming conventions} 

{pstd}
{cmd:StackMe commands expect battery variables to be named} in one of two different ways. Before stacking, 
variables from batteries of questions, one battery question for each battery item (for instance regarding 
different political parties), are expected to all have the same stub-name, with numeric suffixes that generally 
run from 1 to the number of items in the battery (parties that were asked about). Users with variable 
batteries whose items have disperate names (or stubnames with alphabetic suffixes) will need to rename such 
variables before using the {help genstacks:{ul:genst}acks} command (see help {help rename group} especially 
rule 17).{break}
{space 3}{bf:After stacking, each battery of variables} becomes a single ({help reshape}d) variable named with the 
stubname that was used in the names of member items before stacking (see the section on {help stackme##datastacking:data stacking}, 
earlier in this help text). Note that, while the {help genstacks:{ul:genst}acks} command will accept {varlist}s 
of variables named in either fashion, using post-stacking {it:stubname}s for that command requires less typing 
and is more likely to avoid common naming errors.{break}
{space 3}{bf:All other variables generated by stackMe commands} are distinguished by having names that are 
prefixed with (by default) a two-character string separated by an underline character from the remainder of 
the variable name (see {help stackMe##prefixes:variable prefixes}). It follows that the names of variables to be 
pre-processed by {bf:stackMe} may not themselves contain underline characters. A simple way to address any resulting 
problems is to replace all underline characters ("_") occurring in variable names by dollar signs ("$") – the only 
other non-aphanumeric character that {bf:Stata} allows in variable names).{p_end}

{marker Variablelists}
{marker syntax}
{title:Variable lists and option lists}

{pstd}
Every StackMe command-line must start with the name of the stackme command to be executed in the manner determined by the 
rest of the command-line. That command-name should be followed by a standard Stata {varlist} ({help genstacks:{ul:genst}acks} 
and {help gendummies:{ul:gendu}mmies} have {it:{help namelist}} alternatives, as already mentioned). The varlist may end 
with standard Stata {help [ifinwt]} expressions and can be followed by a comma and standard Stataoptionslist, exactly 
like the vast majority of Stata's estimation commands. However, unlike that vast majority, the option-list can be followed 
by a pair of vertical lines ("||") known as "pipes" and another <varlist,optionslist>. The presence of additiional 
pipe-delimited <varlist,optionslist> pairs signals to {bf:stackMe} that the additional varlist(s) are to be processed 
according to exactly the same {help [ifin]} expressions as were provided following the first {varlist} (one of the "tricks" 
that {bf: stackMe} uses to minimize execution time). It follows that the second and any subsequent {varlist}s should not 
include {help if} and {help in} expressions of their own, although they may include {help weight} expressions. Alternatively 
(a third layout possibility for {bf: stackMe} command-lines), the first {varlist}-[ifinwt] pair can itself be followed by a 
pipes delimiter ("||") and any number of additional pipe-delimeted {varlist}[wt] pairs before the final comma that introduces 
the only optionslist permitted with this syntactical layout. This version of a {bf:stackMe} command-line facilitates the 
processing of multiple batteries of variables in precisely the same fashion (a common requirement with survey data). The two 
layout variants for a {bf:stackMe} command-line are illustrated in the following syntax maps:{p_end}

{p 7 13}
{opt gendi:st} {varlist} {ifin} [wt] {bf:, options} || {varlist} [wt] {bf:[, options} || ...{p_end}

{p 9}
or{p_end}

{p 7 13}
{opt genst:acks} {varlist} {ifin} [wt] || [ {varlist} [wt] [ || {varlist} [wt] || ... || {varlist} [wt], options{p_end}

{pstd}
Note that the standard Stata commamd-line syntax is a straightforward variant of each {cmd:stackMe} {varlist} syntax shown 
above. It is what we get when no pipes are used to repeat either the varlist-option pairs or the repeated varlists. Note also that 
the stata commandnames chosen for each example are appropriate for the command-line layout used in that example. With 
{opt gendi:st} it is usual to be calculating proximities to selfplacements that will need to be identified using a different 
{opt sel:fplace} option for each battery; with {opt genst:acks} it is usual to be stacking a number of variable batteries 
using the same options for each battery. But bear in mind (as mentioned earlier) that the {opt genst:acks} command also has 
a layout variant of its own that will normally be preferable to either of the above: using a single list of the stubnames that 
will be used to name those variables after stacking.{p_end}

{marker prefixes}
{title: Variable prefixes}

{pstd}         
As mentioned earlier, variables generated by {bf: stackMe} commands are generally identified by names created by 
prefixing the name of the corresponding input variable initially by two characters followed by an underline 
character. Those two characters identify the command that transformed the input in question and the manner in which 
it was transformed. As that outcome variable is itself further transformed by subsequent {bf:stackMe} commands, 
according to the {help stackMe##Workflow:workflow} described earlier, the two character prefix morphs into a one 
character prefix and is itself prefixed by the two characters identifying the subsequent transformation. So variables 
generated by {bf:stackMe} carry their workflow history in the characters prepended to their names (more detailed 
information is stored in their variable labels).{p_end}
  
{smcl}
{pstd}
{bf:NOTE THAT} the user can option a textual replacement for all current prefixes of outcomes generated by the current 
command (unless that command is {cmdab:genme:anstats} or {cmdab:genstacks}) by invoking option {opt apr:efix()} 
in any command supporting that option. The replacement text must start with an alphabetic character and contain only 
alphabetic and numeric character(s), along with "_" and/or "&". The text will replace the entire character string 
prefixing the names of all variables generated by the varlist (or varlist-option pair) for which the replacement text 
was optioned. This lets the user prefix their outcomes by names that are theoretically meaningful, if desired.{p_end}


{marker stackmespecialnames}
{title:stackMe special names}

{pstd}
Several "special names" are employed for variables generated by {cmd:stackMe}. These names should be avoided when 
picking names for substantive variables within a dataset that will be processed by {cmd:stackMe}. Some of these 
are names reserved for variables added to datasets that have been reshaped by the {cmdab:genst:acks} command. A 
"special prefix" modifies the name of a stacked dataset to flag the fact that the data have been stacked. These 
names are as follows:{p_end}

{p 4 10} 
{bf:SMunit} The {it:observation number} (or 'i' variable described in Stata's {help reshape} command). This variable 
is identical to the value of the Stata system variable {help _n} when not associated with {help by}. In survey 
research each observation will generally have been given a {it:respondent id number} that might be identical to 
{it:{cmd:SMunit}} but the presence or absence of such a respondent ID is ignored and unaffected by {cmd:stackMe} 
commands.{p_end}

{p 4 10} 
{bf:SMstkid} The {it:stack identifier} (or 'j' variable described in Stata's {help reshape} command) identifies 
each of what were members of a battery of integer-suffixed stub-names. If those suffixes were sequential numbers 
starting with '1' for the first suffix, values of SMstkid may match the original suffix-values but some values 
in the unstacked sequence can be absent from the stacked sequence for particular contexts if those values were 
completely missing from that context.{p_end}

{p 4 10}
{bf:SMnstks} The {it:{bf:maximum} number of stacks}, constant across units within stacks, found for {it:{bf}}any 
context.{p_end}

{p 4 10}
{bf:SMitem} An alias for the name of an already existing variable that provides an alternative link to battery-specific 
items, complementary to the link provided by SMstkid. This alternative link is often used to identify the value labels 
associated with specific levels (values) that were battery items before stacking (e.g. party names). This user-supplied
linkage variable is named using option {cmdab:ite:mname}. This "special name" can be used as an alternative to the 
variable's original name in stacked data. Used as an alias in this way, it may not be abbreviated.{p_end}

{p 4 10}
{bf:STKD} (and {bf:stkd}) The upper-case version of this prefix, plus an underscore to delimit the end of the prefix,  
is tacked on to the front of the filename of any dataset that is reshaped by {help genstacks}. Any variable stacked by 
{cmdab:genst:acks} has the lower-case version of this prefix tacked on to the front of its {bf:variable label}, followed 
by a space to delimit the end of the prefix.{p_end}

{p 4 10}
{bf:NOTE:} Further variables with special names are added by command {help genstacks:{ul:genst}acks} when producing 
doubly-stacked data. The doubly-stacked counterparts to the special names listed above are distinguished by replacing the 
second letter ('M' in the above examples) by the number '2' ({it:{cmd:S2stkid}}, {it:{cmd:S2nstks}}, etc.). Also, special 
names like "SMddMisCount" and "SMiiMisPlugCount" are generated by {bf:stackMe} commands for variables that document the 
extent of missing data found, overall, when generating the primary outcome variable(s) for each command.{p_end}

{marker Diagnostics}
{title:Diagnostic checks}

{pstd}({bf:Forthcoming}){p_end}

{marker Regardingversion2}
{title:Note regarding version 2.0}

{pstd}
This release of {cmd:StackMe} is actually Version 2 of what was originally a package named {cmd:PTVtools} – the acronym 
stands for Propensity To Vote (Eijk et al 2006). It differs from {cmd:PTVtools} in having additional commands – 
{help genmeanstats:{ul:genme}anstats} and {help genplace:{ul:genpl}ace} (which also provides an interface to other 
{bf:Stata} commands and to user-written programs). {cmd:StackMe}’s user interface has been standardized across 
{cmd:StackMe} commands: pipe-delimited {varlist}s are available with all {cmd:StackMe} commands, not just with 
{cmd:genyhats}; all {cmd:StackMe} commands offer the same suite of options, invoked by the same option-names, to the 
extent that each option makes sense for the command concerned. The package also provides additional functionality by 
providing for {ifin} and {weight} expressions, along with double-stacking of datasets with nested contextual hierarchies.{break}
{space 3}The concept of a "utility program" has been introduced, named with initial characters "SM" instead of "gen", 
and providing various services to users. Considerable effort has been put into early diagnosis of variable naming 
errors: {bf:stackMe} commands are no longer apt to run to completion before reporting a naming error.{break}
{space 3}In a departure from conventional data analysis packages, the {bf:stackMe} {help stackme##Workflow:workflow}, so 
critical to its objectives, is largely self-documenting; with variables having string-prefixes (conceptually similar to 
to tree-rings) one character for each {bf:stackMe} command that has pre-processed the variable concerned. More detailed 
information about each step in a variable's pre-processing history is held in a {bf:Stata} {help char:Data Characteristic} 
and can be displayed by the {help SMorigin:{ul:SMori}gin} utility program, that can also place a summary in the variable's 
label.{break}
{space 3}Most importantly, all {cmd:StackMe} commands now run faster by an order of magnitude or greater. This is especially 
true for {help genstacks}, {help geniimpute} and {help genyhats} (the commands most likely to involve all substantively 
relevant variables in a {cmd:StackMe} dataset). The extra speed comes in part from various elaborations made to standard 
{bf:Stata} syntax. These elaborations can be ignored if the fastest possible execution is not a primary concern.{p_end}

{pstd}
{space 3}{bf:FOR PAST USERS OF PTVTOOLS:} A couple of minor changes (additional to the major innovations involving 
multiple varlists) have been made to the syntax of {bf:PTVtools} commands. In {help gendist:{ul:gendi}st} the 
{cmdab:res:pondent()} option has become a {cmdab:sel:fplace()} option. Instead of prefix strings for outcome variables 
that are always one character in length (e.g. "y_" as a prefix for a 'yhat' outcome), most commands now produce outcomes 
that are initially identified by two-character prefix-strings ({cmdab:gendu:mmies} outcome variables are still, by default, 
prefixed with the the name of the variable from which each dummy was derived). Those two-character prefixes generally 
morph into single-char "reminders" as those variables themselves become inputs for the next stage in the {bf:stackMe} 
{help workflow}. So the typical {bf:stackMe} variable is prefixed by a string of single characters, summarizing its past 
workflow history, themselves prefixed by two-characters more definitively identifying its most recent transformation. The 
command {cmdab:genme:anstats}, whose outcomes are univariate statistics that seldom themselves become varlist inputs, 
retain those two-character abbreviations for each statistic that they produce.{break}

{pstd}
Initially we are distributing a beta version of {cmd:StackMe} 2.0, which may still contain bugs and 
infelicities. Any comments and/or suggestions for improvements should be emailed to mark.franklin@trincoll.edu 
(if no response within a week, email the first author named below).{break}


{marker References}
{title:References}

Eijk, Cees van der et al. (2006) "Rethinking the dependent variable in voting behavior: On the measurement and 
analysis of electoral utilities." {it:Electoral Studies} (25:3) 434-447.
King, Gary, et al. (2001) "Analyzing incomplete political science data: An alternative algorithm for multiple 
imputation." {it:American political science review} (95:1) 49-69.

{marker Authors}
{title:Authors}

{pstd}
Lorenzo De Sio - European University Institute (now at LUISS): ldesio(at)luiss.it{break}
Mark Franklin - European University Institute (now emeritus at Trinity College Connecticut): mark.franklin(at)trincoll.edu

{marker citation}
{title:Citations}

{pstd}
If you employ {bf:StackMe} in published work, please use the following citation:{break}
De Sio, L. and Franklin, M. (2011) "StackMe: A Stata package for manipulating multi-level data" 
(version 2.0), {it:Statistical Software Components}, Boston College Department of Economics.

{pstd}
To better understand generic variable analysis in a comparative framework see:{break}
Eijk, C. van der, Brug, W. van der, Kroh, M. and Franklin, M. (2006) "Rethinking the dependent variable in voting 
behavior: On the measurement and analysis of electoral utilities", {it:Electoral Studies} 25(3): 424-447.{p_end}
