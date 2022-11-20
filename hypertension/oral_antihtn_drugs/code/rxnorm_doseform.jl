# Take in a file with a list of RxNorm codes and query doseForm information from RxNorm rest api

using HTTP, CSV, DataFrames, Printf

function add_dose_forms!(rxnorm_df)
    base_url = "https://rxnav.nlm.nih.gov/REST/rxcui/"
    url_suffix = "/historystatus.json"
    interval = 20

    rxnorm_df[!,"drugName_str"] .= ""
    rxnorm_df[!,"doseFormRxCui_str"] .= ""
    rxnorm_df[!,"doseFormName_str"] .= ""

    for i in 1:size(rxnorm_df)[1]
        if i % interval == 0
            # respect REST API guidelines
            sleep(1)
        end

        t_url = base_url*"$(rxnorm_df.CONCEPT_CODE[i])"*url_suffix
        #t_url = "https://rxnav.nlm.nih.gov/REST/rxcui/29046/historystatus.json" # example rest address
        rest_body = String(HTTP.request("GET", t_url).body)
        
        # pull out drug name
        drugName_matches = []
        for match in eachmatch(r"(?<=\"name\":\").+?(?=\")",rest_body)
            push!(drugName_matches,match)
        end
        for j in 1:length(drugName_matches)
            drugName_matches[j] = drugName_matches[j].match
        end
        drugName_matches_str = join(drugName_matches,"|")

        # pull out doseFormRxCui(s)
        doseFormRxCui_matches = []
        for match in eachmatch(r"(?<=doseFormRxcui\":\")\d+",rest_body)
            push!(doseFormRxCui_matches,match)
        end
        for j in 1:length(doseFormRxCui_matches)
            doseFormRxCui_matches[j] = doseFormRxCui_matches[j].match
        end
        doseFormRxCui_str = join(doseFormRxCui_matches,"|")

        # pull out doseFormName(s)
        doseFormName_matches = []
        for match in eachmatch(r"(?<=doseFormName\":\")[A-z ]+(?!=})",rest_body)
            push!(doseFormName_matches,match)
        end
        for j in 1:length(doseFormName_matches)
            doseFormName_matches[j] = doseFormName_matches[j].match
        end
        doseFormName_str = join(doseFormName_matches,"|")

        rxnorm_df.drugName_str[i] = drugName_matches_str
        rxnorm_df.doseFormRxCui_str[i] = doseFormRxCui_str
        rxnorm_df.doseFormName_str[i] = doseFormName_str

        println("$(i) $(doseFormRxCui_str) $(drugName_matches_str)")

    end

end

function main(rxnorm_file,rxnorm_out_file)
    rxnorm_df = CSV.read(rxnorm_file,DataFrame)
    filter!(row -> row.VOCABULARY_ID == "RxNorm", rxnorm_df)

    add_dose_forms!(rxnorm_df)
    replace!(rxnorm_df.doseFormName_str, missing => "")

    # filter results, from 4842 -> 4618 rows
    non_oral_doseFormName_set = Set(["Injectable Solution", "Ophthalmic Solution", "Ophthalmic Suspension", "Topical Foam", "Topical Solution", "Topical Spray", "Prefilled Syringe", "Injection","Cartridge"])
    for exclude in non_oral_doseFormName_set
        filter!(row -> !contains(row.doseFormName_str, exclude), rxnorm_df)
    end

    ##########################
    ### missing dose forms ###
    ##########################
    ## those containing "ML" or "Injection" (100% overlap), or "Injectable" in the drug name are not oral medications likely to be corresponding to first or second-line oral antihypertension treatment, from 4618 -> 4495
    non_oral_drugName_set = Set(["ML","Injection","Injectable","Topical","Syringe"])
    for exclude in non_oral_drugName_set
        filter!(row -> row.doseFormName_str != "" || (row.doseFormName_str == "" && !contains(row.drugName_str, exclude)), rxnorm_df)
    end

    ## The remaining drugs appear to all be oral
    ## those containing "Oral" or "Tablet" or "Pill" are confirmed oral medications likely to be corresponding to first or second-line oral antihypertension treatment. Of 1580 missing doseForms, 1054 of them contain of the following words that appear to reliably indicate oral medications
    oral_drugName_set = Set(["Oral","Tablet","Pill","Chewable","Sublingual"])
    size(filter(row -> row.doseFormName_str == "" && (contains(row.drugName_str,"Oral") || contains(row.drugName_str,"Tablet") || contains(row.drugName_str,"Pill") || contains(row.drugName_str,"Chewable") || contains(row.drugName_str,"Sublingual")),rxnorm_df))

    ## those containing "MG" but NOT "ML" or "Injection" or "Injectable" are probably oral medications corresponding to first or second-line oral antihypertension treatment. Of the remaining 526, all contain "MG" which without any other indication can probably be considered oral forms of the medications and will be included. A stricter defintion could exclude these remaining but they are included for now.
    size(filter(row -> row.doseFormName_str == "" && (!contains(row.drugName_str,"Oral") && !contains(row.drugName_str,"Tablet") && !contains(row.drugName_str,"Pill") && !contains(row.drugName_str,"Chewable") && !contains(row.drugName_str,"Sublingual")),rxnorm_df))

    CSV.write(rxnorm_out_file,rxnorm_df)
end

main(ARGS[1],ARGS[2])