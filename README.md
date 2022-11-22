# DrugConceptSets
Guidelines driven standard concept sets for electronic realth records research

## Hypertension

### Oral antihypertension drugs concept set
- List of oral hypertension drugs is referenced from Table 18 of the 2017 ACC/AHA guideline for the prevention, detection, evaluation, and management of high blood pressure in adults (https://www.jacc.org/doi/full/10.1016/j.jacc.2017.11.006?_ga=2.1275)
- Table of primary and secondary oral hypertension drugs was converted to ATC codes using https://www.whocc.no/ on 11/17/2022
- ATC codes were converted to RxNorm ingredients using the Athena vocabulary in an OHDSI OMOP CDM.
- All children of the RxNorm ingredients were determined using the same CDM.
- RxNorm cuis were then queried for doseForm from the RxNorm rest api (e.g. https://rxnav.nlm.nih.gov/REST/rxcui/29046/historystatus.json)
- Methods for determining oral forms of drugs from the rest api results are detailed in code comments
