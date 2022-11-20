# Aaron Eisman
# The purpose of this program is to generate a list of RxNorm codes that correspond to first and second line oral hypertensino treatment in the United State according to "Table 18 - Oral Antihypertensive Drugs" from Whelton et al. 2017 High Blood Pressure Clinical Practice guidelines

get_all_children <- function(connectionDetails,cdmDbSchema,code_list,dbms){
    code_list = unique(code_list)
    code_list_n_prior = length(code_list) - 1
    iter = 0

    code_list_all_df = data.frame(matrix(nrow = 0, ncol = 5))

    while (code_list_n_prior < length(code_list)) {
        code_list_n_prior = length(code_list)

        sql <- "SELECT
            d.concept_id       AS child_concept_id,
            d.concept_name     AS child_concept_name,
            d.concept_code     AS child_concept_code,
            d.concept_class_id AS child_concept_class_id,
            d.vocabulary_id    AS child_concept_vocab_id
        FROM @cdm_db_schema.concept_ancestor AS ca
            JOIN @cdm_db_schema.concept AS d ON ca.descendant_concept_id = d.concept_id
        WHERE
            ca.min_levels_of_separation = 1 AND
            ca.ancestor_concept_id IN (@codeList) AND
            d.invalid_reason IS NULL
        ;"

        conn <- connect(connectionDetails)
        sql = render(sql, cdm_db_schema = cdmDbSchema, codeList = code_list)
        sql = translate(sql, targetDialect = dbms)
        code_list_df = querySql(conn,sql)
        code_list = unique(c(code_list,code_list_df$CHILD_CONCEPT_ID))
        disconnect(conn)

    }
    return(code_list)
}

source_to_standard <- function(connectionDetails,cdmDbSchema,codes,source,dbms){
    sql <- "SELECT DISTINCT
                c1.domain_id        AS source_domain_id,
                c2.concept_id       AS concept_id,
                c2.concept_name     AS concept_name,
                c2.concept_code     AS concept_code,
                c2.concept_class_id AS concept_class_id,
                c2.vocabulary_id    AS concept_vocabulary_id,
                c2.domain_id        AS concept_domain_id
            FROM @cdm_db_schema.concept_relationship AS cr
                JOIN @cdm_db_schema.concept AS c1 ON c1.concept_id = cr.concept_id_1
                JOIN @cdm_db_schema.concept AS c2 ON c2.concept_id = cr.concept_id_2
            WHERE
                cr.relationship_id = 'Maps to' AND
                c1.concept_code IN (@sourceCode) AND
                c1.vocabulary_id = @sourceVocab AND
                cr.invalid_reason IS NULL
            ;"
    conn <- connect(connectionDetails)
    sql = render(sql, cdm_db_schema = cdmDbSchema, sourceCode = codes, sourceVocab = source)
    sql = translate(sql, targetDialect = dbms)
    standard_code_df = querySql(conn,sql)
    disconnect(conn)

    return(standard_code_df)
}

read_annotated_atc_file <- function(file){
    atc_codes = c()
    for (line in readLines(file)){
        if (grepl("YES",line) && !grepl("#",line)){
            t_atc = paste(regmatches(line,regexec('\\w\\d\\d\\w\\w\\d\\d',line)))
            atc_codes = c(atc_codes,paste("'",t_atc,"'",sep=""))
        }
    }

    return(atc_codes)
}

main <- function(){
    library(DatabaseConnector)
    library(SqlRender)

    #import specific database environment connection details and ATC code source file
    source(oral_anihtn_drugs.conf)

    atc_codes = read_annotated_atc_file(file)

    user <- charToRaw(rstudioapi::askForPassword("Enter CDM DB Username"))
    pw <- charToRaw(rstudioapi::askForPassword("Enter CDM DB Password"))

    connectionDetails <-
    DatabaseConnector::createConnectionDetails(
        dbms = dbms,
        server = server,
        user = rawToChar(user),
        password = rawToChar(pw),
        port = port
    )

    conn <- connect(connectionDetails)
    standard_ids = source_to_standard(connectionDetails,cdmDbSchema,atc_codes,"'ATC'",dbms)$CONCEPT_ID
    all_children_ids = get_all_children(connectionDetails,cdmDbSchema,standard_ids,dbms)
    disconnect(conn)

    #get codes, concept ids and vocabulary
    sql <- "SELECT concept_id, concept_code, vocabulary_id FROM @cdm_db_schema.concept WHERE concept_id IN (@ids);"
    conn <- connect(connectionDetails)
    sql = render(sql, cdm_db_schema = cdmDbSchema, ids = all_children_ids)
    sql = translate(sql, targetDialect = dbms)
    oral_anti_htn_codes_df = querySql(conn,sql)
    disconnect(conn)

    #limit to RxNorm only (no RxNorm extension)
    oral_anti_htn_codes_df[oral_anti_htn_codes_df$VOCABULARY_ID == "RxNorm",]

    ## WHEN WORKING IN A SERCURE ENVIRONMENT WITHOUT INTERNET ACCESS, THIS CODE LIST (oral_anti_htn_codes_df) NEEDS TO BE EXPORTED TO AN ENVIRONMENT THAT CAN ACCESS THE RXNORM REST API. THIS IS USED TO DETERMINE THE DOSEFORM OF EACH RXNORM CUI AND LIMIT TO DRUGS THAT ARE ORAL ROUTE. A SEPARATE SCRIPT rxnorm_doseform.jl IS PROVIDED TO PERFORM THIS TASK

    antihtn_codes_doseform = read.csv(file = "data/antihtn_codes_doseform.csv")


}

main()
    