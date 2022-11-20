# drug_concept_sets
Guidelines Driven Standard Concept Sets for Electronic Health Records Research

## Hypertension

### Oral antihypertension medications concept set
- List of oral hypertension medications is referenced from Table 18 of the 2017 ACC/AHA guideline for the prevention, detection, evaluation, and management of high blood pressure in adults (https://www.jacc.org/doi/full/10.1016/j.jacc.2017.11.006?_ga=2.1275)
- Table of primary and secondary oral hypertension medications was converted to ATC codes using https://www.whocc.no/ on 11/17/2022
- ATC codes were converted to RxNorm ingredients using the Athena vocabulary in an OHDSI OMOP CDM.
- All children of the RxNorm ingredients were determined using the same CDM.
- RxNorm cuis were then queried for doseForm from the RxNorm rest api (e.g. https://rxnav.nlm.nih.gov/REST/rxcui/29046/historystatus.json)
- Details for determining oral forms of medications from the rest api results are detailed in code comments
