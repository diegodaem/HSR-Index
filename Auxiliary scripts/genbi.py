import requests
import pandas as pd
from Bio import Entrez
from Bio import SeqIO
from tqdm import tqdm
import concurrent.futures
import re
import json
import openpyxl
import time

Entrez.email = "diegodaem@gmail.com"
Entrez.api_key = "9d7902e9d1f83671955ddc04a9f34e3d0d08"

info_secuencias = {}

gene_variants = [
    # Variantes para COI
    "cytochrome oxidase subunit 1", "cytochrome c oxidase I", "COI", "COX1", "MTCO1", "MT-CO1", "cytochrome c oxidase subunit I", "coi", "(coi)", "(coi) gene", "cytochrome oxidase subunit 1 (COI) gene",
    # Variantes para CYTB
    "cytochrome b", "Cytochrome b", "CYTB", "cytb", "cytochrome B", "MT-CYB", "mt-cyb", "cytochrome b gene", "(cytb)", "(cytb) gene", "mt-Cytb"
]

coi_variants = gene_variants[:11] 
cytb_variants = gene_variants[11:]

#---Part 1: Functions for ITIS

import requests
import time

def obtener_sinonimias(tsn_especie):
    MAX_REINTENTOS = 5  # Número máximo de reintentos
    ESPERA = 5  # Tiempo de espera en segundos entre reintentos
    TIMEOUT = 10  # Tiempo de espera en segundos para la solicitud HTTP

    for intento in range(MAX_REINTENTOS):
        try:
            url = f"https://www.itis.gov/ITISWebService/jsonservice/getFullRecordFromTSN?tsn={tsn_especie}"
            respuesta = requests.get(url, timeout=TIMEOUT)
            data = respuesta.json()

            sinonimias = []
            if data.get('synonymList') and data['synonymList'].get('synonyms'):
                for sinonimo in data['synonymList']['synonyms']:
                    if sinonimo:
                        sinonimias.append(sinonimo['sciName'])
            return sinonimias

        except requests.exceptions.Timeout:
            print(f"Tiempo de espera agotado para la solicitud. Intento {intento + 1} de {MAX_REINTENTOS}.")
            time.sleep(ESPERA)

        except requests.exceptions.RequestException as e:
            print(f"Error en la solicitud: {e}. Intento {intento + 1} de {MAX_REINTENTOS}.")
            time.sleep(ESPERA)

    print(f"Error: No se pudo obtener las sinonimias para el TSN: {tsn_especie} después de {MAX_REINTENTOS} intentos.")
    return []

def obtener_especies_desde_tsn(tsn, total_tsn):
    def obtener_especies_recursivamente(tsn, progress_bar):
        url = f"https://www.itis.gov/ITISWebService/jsonservice/getHierarchyDownFromTSN?tsn={tsn}"
        respuesta = requests.get(url)
        data = respuesta.json()

        especies = []
        if data.get('hierarchyList'):
            for registro in data['hierarchyList']:
                if registro and registro['rankName'].strip().lower() != 'species':
                    especies.extend(obtener_especies_recursivamente(registro['tsn'], progress_bar))
                elif registro:
                    especie_info = {
                        'tsn': registro['tsn'],
                        'nombre_cientifico': registro['taxonName'].strip(),
                        'sinonimias': obtener_sinonimias(registro['tsn'])
                    }
                    especies.append(especie_info)
                    progress_bar.update(1)  # Update the progress bar
        return especies

    max_workers = 1
    especies = []

    with tqdm(total=total_tsn) as progress_bar:  # Initialize the progress bar with the total number of TSNs
        with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
            futures = [executor.submit(obtener_especies_recursivamente, tsn, progress_bar)]
            for future in concurrent.futures.as_completed(futures):
                especies.extend(future.result())
    
    for especie in especies:
        sinonimias = obtener_sinonimias(especie['tsn'])
        especie['sinonimias'] = sinonimias

    return especies

def obtener_cantidad_tsn(tsn):
    url = f"https://www.itis.gov/ITISWebService/jsonservice/getHierarchyDownFromTSN?tsn={tsn}"
    respuesta = requests.get(url)
    data = respuesta.json()

    contador = 0
    if data.get('hierarchyList'):
        for registro in data['hierarchyList']:
            if registro and registro['rankName'].strip().lower() != 'species':
                contador += obtener_cantidad_tsn(registro['tsn'])
            elif registro:
                contador += 1
    return contador

def obtener_nombre_taxon(tsn):
    url = f"https://www.itis.gov/ITISWebService/jsonservice/getScientificNameFromTSN?tsn={tsn}"
    respuesta = requests.get(url)
    data = respuesta.json()

    if 'combinedName' in data:
        return data['combinedName']
    else:
        raise ValueError(f"The taxon name could not be obtained for the TSN: {tsn}")

def obtener_info_taxonomica(tsn):
    url = f"https://www.itis.gov/ITISWebService/jsonservice/getTaxonomicRankNameFromTSN?tsn={tsn}"
    respuesta = requests.get(url)
    data = respuesta.json()

    if 'rankName' in data:
        rank_name = data['rankName']
        combined_name = obtener_nombre_taxon(tsn)
        return rank_name, combined_name
    else:
        raise ValueError(f"No taxonomic data found for the TSN: {tsn}")

#---Part 2: Functions for GenBank

def search_genbank(species, method, progress_bar,retmax=100, retstart=0):
    ids = []

    for gene_variant in gene_variants:
        # Comprobar si la variante genética es una frase o un término único
        if ' ' in gene_variant:
            # Dividir la frase en términos individuales
            gene_terms = gene_variant.split()
            query_terms = [f"{term}[All Fields]" for term in gene_terms]
            query = f"{' AND '.join(query_terms)} AND {species}[ORGN]"
        else:
            # Tratar como un término único
            query = f"{gene_variant}[Gene] AND {species}[ORGN]"

        try:
            search_result = Entrez.esearch(db="nucleotide", term=query, retmax=retmax, retstart=retstart, usehistory="y")
            record = Entrez.read(search_result)
            search_result.close()
            ids.extend([(id, method) for id in record["IdList"]])  # Modification to include the method

            #print(f"Query: {query}, Number of IDs found: {len(record['IdList'])}")

            # Check if more results are available and retrieve them
            while int(record['Count']) > retstart + retmax:
                retstart += retmax
                search_result = Entrez.esearch(db="nucleotide", term=query, retmax=retmax, retstart=retstart, usehistory="y", webenv=record['WebEnv'], query_key=record['QueryKey'])
                record = Entrez.read(search_result)
                search_result.close()
                ids.extend([(id, method) for id in record["IdList"]])  # Modification to include the method
        except Exception as e:
            print(f"Error en la búsqueda de {query}: {e}")
            continue
        finally:
            progress_bar.update(1)

    return ids  # Returns a list of tuples (id, method)

def fetch_sequence(accession):
    handle = Entrez.efetch(db="nucleotide", id=accession, rettype="gb", retmode="text")
    record = SeqIO.read(handle, "genbank")
    handle.close()
    return record

def extract_info(record, valid_species_name, search_method, incluir_mitocondriales='Yes'):
    accession = record.id

    if accession in info_secuencias:
        return None

    species_name = valid_species_name
    if search_method == 'From ITIS' and record.annotations.get('organism', '').lower() != valid_species_name.lower():
        species_name += "*"

    description_lower = record.description.lower()
    if any(cytb_variant.lower() in description_lower for cytb_variant in cytb_variants):
        gene = 'CYTB'
    elif any(coi_variant.lower() in description_lower for coi_variant in coi_variants):
        gene = 'COI'
    else:
        gene = 'Unknown'

    #print(f"Accession {accession}, Gene: {gene}")
    
    # Extraction of the specimen voucher
    specimen_voucher = 'NA'
    for feature in record.features:
        if feature.type == 'source':
            specimen_voucher = feature.qualifiers.get('specimen_voucher', ['NA'])[0]
            break

    # Extract geographical information
    country, state, locality = 'NA', 'NA', 'NA'
    if 'country' in record.features[0].qualifiers and record.features[0].qualifiers['country']:
        location = record.features[0].qualifiers['country'][0]
        country_parts = location.split(':')

        if len(country_parts) > 0:
            country = country_parts[0].strip()
        if len(country_parts) > 1:
            state_locality_parts = country_parts[1].split(',')
            if len(state_locality_parts) > 0:
                state = state_locality_parts[0].strip()
            if len(state_locality_parts) > 1:
                locality = ', '.join(state_locality_parts[1:]).strip()
    
    # Extraction of latitude and longitude
    lat_lon = record.features[0].qualifiers.get('lat_lon', ['NA'])[0]
    lat_lon_match = re.match(r'([0-9.-]+ [NS]) ([0-9.-]+ [WE])', lat_lon)
    latitude = lat_lon_match.group(1) if lat_lon_match else 'NA'
    longitude = lat_lon_match.group(2) if lat_lon_match else 'NA'

    # Extraction of the number of bases of the sequence
    num_bases = len(record.seq)

    # Lower Filter: Exclude sequences shorter than 600 base pairs
    if num_bases < 590:
        return None
    
    # Upper Filter: Apply if the user chooses to exclude mitochondrial sequences
    if incluir_mitocondriales.lower() == 'No':
        if num_bases > 1300:
            return None
        
    gene = 'Unknown'
    description_lower = record.description.lower()
    if any(cytb_variant.lower() in description_lower for cytb_variant in cytb_variants):
        gene = 'CYTB'
        # Filtro específico para secuencias CYTB: eliminar si <1100 o >1200 bases
        num_bases = len(record.seq)
        if num_bases < 1000 or num_bases > 1200:
            return None
    elif any(coi_variant.lower() in description_lower for coi_variant in coi_variants):
        gene = 'COI'
    
    # Additional Filter: Exclude sequences that contain specific terms in their title
    unwanted_terms = ['von willebrand factor', 'nad', 'NADH','12s', '16s', 'rRNA', 'tRNA', 'ribosomal', 'COX2', 'COXII', 'COXIII', 'COX3']
    for term in unwanted_terms:
        if term.lower() in record.description.lower():
            return None 
    
    # Date
    release_date = 'NA'
    for feature in record.features:
        if feature.type == 'source' and 'collection_date' in feature.qualifiers:
            release_date = feature.qualifiers['collection_date'][0]
            break

    # Extraction of the BOLD code, if available
    bold_code = 'NA'
    for feature in record.features:
        if 'db_xref' in feature.qualifiers:
            db_xrefs = feature.qualifiers['db_xref']
            for xref in db_xrefs:
                if xref.startswith('BOLD:'):
                    bold_code = xref.split(':')[1].split('.')[0]
                    break

    # Construct the list of information
    info = [accession, species_name, search_method, gene, specimen_voucher, country, state, locality, latitude, longitude, num_bases, release_date, bold_code]

    # Store the information in the global dictionary if the Accession is new
    info_secuencias[accession] = info

    return info

def search_genbank_directly(order_name, progress_bar):
       
    # Initialize a set to store unique Access IDs
    all_ids = set()
    # Loop to perform multiple searches, one for each variant of the gene
    for gene_variant in gene_variants:
        # Form the query to include the order and the gene variant
        query = f"{order_name}[ORGN] AND {gene_variant}[Gene]"
        try:
            # Search in GenBank
            search_result = Entrez.esearch(db="nucleotide", term=query, retmax=10000)
            record = Entrez.read(search_result)
            search_result.close()
            # Add the found IDs to the set, avoiding duplicates
            all_ids.update(record["IdList"])
        except Exception as e:            
            print(f"Error in the direct GenBank search for the query '{query}': {e}")
        finally:
            progress_bar.update(1)
    
    # Return the set of Access IDs after completing all searches
    return [(id, 'Direct GenBank Search') for id in all_ids] 

def get_families_from_order(order_name):
    families = []
    try:
        # Perform a search to obtain all entries at the family level for the order
        query = f"{order_name}[ORGN] AND family[Rank]"
        search_handle = Entrez.esearch(db="taxonomy", term=query, retmax=500, retmode="xml")
        search_results = Entrez.read(search_handle)
        search_handle.close()

        if not search_results["IdList"]:
            print(f"No families found for the order '{order_name}'")
            return families

        # Obtain details of each found ID
        for tax_id in search_results["IdList"]:
            fetch_handle = Entrez.efetch(db="taxonomy", id=tax_id, retmode="xml")
            fetch_results = Entrez.read(fetch_handle)
            fetch_handle.close()

            for result in fetch_results:
                if result["Rank"] == "family":
                    families.append(result["ScientificName"])

    except Exception as e:
        print(f"Error in obtaining families for the order {order_name}: {e}")

    return families

def search_genbank_family(family_name):
    # Initialize a set to store unique Access IDs
    family_ids = set()
    
    # Loop to perform multiple searches, one for each variant of the gene
    for gene_variant in gene_variants:
        # Formulate the query to include the family and the gene variant
        query = f"{family_name}[ORGN] AND {gene_variant}[Gene]"
        try:
            # Search in GenBank
            search_result = Entrez.esearch(db="nucleotide", term=query, retmax=10000)
            record = Entrez.read(search_result)
            search_result.close()
            # Add the found IDs to the set, avoiding duplicates
            family_ids.update(record["IdList"])
        except Exception as e:            
            print(f"Error en la búsqueda de GenBank para la familia '{family_name}' con la variante '{gene_variant}': {e}")
    
    # Return the set of Access IDs after completing all searches
    return [(id, 'Family Search') for id in family_ids]

def get_genera_from_family(family_name):
    genera = []
    try:
        # Search to obtain all entries at the genus level for the family
        query = f"{family_name}[ORGN] AND genus[Rank]"
        search_handle = Entrez.esearch(db="taxonomy", term=query, retmax=500, retmode="xml")
        search_results = Entrez.read(search_handle)
        search_handle.close()

        if not search_results["IdList"]:
            print(f"No genera found for the family '{family_name}'")
            return genera

        # Obtain details of each found ID
        for tax_id in search_results["IdList"]:
            fetch_handle = Entrez.efetch(db="taxonomy", id=tax_id, retmode="xml")
            fetch_results = Entrez.read(fetch_handle)
            fetch_handle.close()

            for result in fetch_results:
                if result["Rank"] == "genus":
                    genera.append(result["ScientificName"])

    except Exception as e:
        print(f"Error in obtaining genera for the family {family_name}: {e}")

    return genera

def search_genbank_genus(genus_name):
    # Initialize a set to store unique Access IDs
    genus_ids = set()
    
    # Loop to perform multiple searches, one for each gene variant
    for gene_variant in gene_variants:
        # Formulate the query to include the genus and the gene variant
        query = f"{genus_name}[ORGN] AND {gene_variant}[Gene]"
        try:
            # Search in GenBank
            search_result = Entrez.esearch(db="nucleotide", term=query, retmax=10000)
            record = Entrez.read(search_result)
            search_result.close()
            # Add the found IDs to the set, avoiding duplicates
            genus_ids.update(record["IdList"])
        except Exception as e:
            print(f"Error en la búsqueda de GenBank para el género '{genus_name}' con la variante '{gene_variant}': {e}")
    
    # Return the set of Access IDs after completing all searches
    return [(id, 'Genus Search') for id in genus_ids]

def main(tsn_orden):
    try:
        categoria_taxonomica, nombre_taxon = obtener_info_taxonomica(tsn_orden)
        respuesta = input(f"{categoria_taxonomica} {nombre_taxon} - Do you wish to continue? (Yes/No): ").strip().lower()

        respuestas_afirmativas = ['YES', 'yes', 'Yes', 'Y', 'y', 'si', 'SI']
        respuestas_negativas = ['NO', 'no', 'No', 'N', 'n', 'NOT', 'Not', 'not']

        if respuesta in respuestas_negativas:
            print("User-initiated process termination.")
            return
        elif respuesta not in respuestas_afirmativas:
            print("Unrecognized response. Process finished.")
            return
    except ValueError as e:
        print(e)
        return
    
    incluir_mitocondriales = input("Do you want to keep information from Metagenomes? (Yes/No): ").strip().lower()
    columnas = ["ACCESSION", "SPECIES_NAME", "Synonims", "GENE", "SPECIMEN_VOUCHER", "COUNTRY", "STATE", "LOCALITY", "LATITUDE", "LONGITUDE", "NUM_BASES", "RELEASE_DATE", "BOLD_code"]
    df_final = pd.DataFrame(columns=columnas)

    print("Executing ITIS Data Retrieval and Synonym Resolution...")
    total_tsn = obtener_cantidad_tsn(tsn_orden)
    especies_con_sinonimias = obtener_especies_desde_tsn(tsn_orden, total_tsn)
    df_especies = pd.DataFrame(especies_con_sinonimias)
    df_especies = df_especies.rename(columns={
        "tsn": "TSN Number",
        "nombre_cientifico": "Scientific Name",
        "sinonimias": "Synonyms"
    })
    df_especies.to_excel("Species_and_synonyms.xlsx", index=False)

    nombres_buscados = set()

    total_variants = len(especies_con_sinonimias) * len(gene_variants)
    with tqdm(total=total_variants, desc="Searching GenBank") as progress_bar:
        for especie in especies_con_sinonimias:
            nombre_valido = especie['nombre_cientifico']
            if nombre_valido not in nombres_buscados:
                nombres_buscados.add(nombre_valido)
                ids_especie = search_genbank(nombre_valido, "From ITIS", progress_bar)
                if ids_especie:
                    for accession in ids_especie:
                        try:
                            record = fetch_sequence(accession)
                            info = extract_info(record, nombre_valido, "From ITIS", incluir_mitocondriales)
                            if info is not None:
                                df_info = pd.DataFrame([info], columns=columnas)
                                df_final = pd.concat([df_final, df_info], ignore_index=True)
                                #print(f"Added sequence: {info}")
                        except Exception as e:
                            print(f"Error {accession}: {e}")
                else:
                    new_row = pd.DataFrame([{**dict.fromkeys(columnas, 'NA'), "SPECIES_NAME": nombre_valido, "Synonims": "No sequences"}])
                    df_final = pd.concat([df_final, new_row], ignore_index=True)

        for sinonimia in especie['sinonimias']:
            if sinonimia not in nombres_buscados:
                nombres_buscados.add(sinonimia)
                ids_sinonimia = search_genbank(sinonimia, "From ITIS", progress_bar)
                if ids_sinonimia:
                    for accession in ids_sinonimia:
                        try:
                            record = fetch_sequence(accession)
                            info = extract_info(record, nombre_valido + "*", "From ITIS", incluir_mitocondriales)
                            if info is not None:
                                df_info = pd.DataFrame([info], columns=columnas)
                                df_final = pd.concat([df_final, df_info], ignore_index=True)
                        except Exception as e:
                            print(f"Error al procesar {accession} para sinonimia {sinonimia}: {e}")
                else:
                    new_row = pd.DataFrame([{**dict.fromkeys(columnas, 'NA'), "SPECIES_NAME": nombre_valido, "Synonims": sinonimia + " (No sequences)"}])
                    df_final = pd.concat([df_final, new_row], ignore_index=True)

    print("Processing direct search in GenBank...")
    with tqdm(total=len(gene_variants), desc="Direct GenBank Search") as progress_bar:
        direct_genbank_ids = search_genbank_directly(nombre_taxon, progress_bar)
        for accession in direct_genbank_ids:
            try:
                record = fetch_sequence(accession)
                info = extract_info(record, record.annotations.get('organism'), "Direct GenBank Search", incluir_mitocondriales)
                if info is not None:
                    df_info = pd.DataFrame([info], columns=columnas)
                    df_final = pd.concat([df_final, df_info], ignore_index=True)
            except Exception as e:
                print(f"Error al procesar {accession} de la búsqueda directa: {e}")

    print("Processing families within the order...")
    families = get_families_from_order(nombre_taxon)
    for family in families:
        print(f"    Processing family: {family}")
        family_ids = search_genbank_family(family)
        for accession in family_ids:
            try:
                record = fetch_sequence(accession)
                info = extract_info(record, record.annotations.get('organism'), "Family Search", incluir_mitocondriales)
                if info is not None:
                    df_info = pd.DataFrame([info], columns=columnas)
                    df_final = pd.concat([df_final, df_info], ignore_index=True)
            except Exception as e:
                print(f"Error al procesar {accession} de la familia {family}: {e}")

    print("Processing genus within order...")
    for family in families:
        genera = get_genera_from_family(family)
        for genus in genera:
            print(f"    Processing genus: {genus}")
            genus_ids = search_genbank_genus(genus)
            for accession in genus_ids:
                try:
                    record = fetch_sequence(accession)
                    info = extract_info(record, record.annotations.get('organism'), "Genus Search", incluir_mitocondriales)
                    if info is not None:
                        df_info = pd.DataFrame([info], columns=columnas)
                        df_final = pd.concat([df_final, df_info], ignore_index=True)
                except Exception as e:
                    print(f"Error al procesar {accession} del género {genus}: {e}")

    df_final.rename(columns={
        "ACCESSION": "GenBank Accession", 
        "SPECIES_NAME": "Species", 
        "GENE": "Locus", 
        "SPECIMEN_VOUCHER": "Specimen Voucher", 
        "COUNTRY": "Country", 
        "STATE": "Province/State", 
        "LOCALITY": "Locality", 
        "LATITUDE": "Latitude", 
        "LONGITUDE": "Longitude", 
        "NUM_BASES": "Num bp", 
        "RELEASE_DATE": "Collect Date", 
        "BOLD_code": "BOLD ID"
    }, inplace=True)
    
    # Separar los datos por gen: COI y CYTB
    df_coi = df_final[df_final['Locus'] == 'COI']
    df_cytb = df_final[df_final['Locus'] == 'CYTB']

    # Crear un archivo Excel con dos pestañas, una para COI y otra para CYTB
    with pd.ExcelWriter('Genbank_sequences.xlsx') as writer:
        df_coi.to_excel(writer, sheet_name='COI', index=False)
        df_cytb.to_excel(writer, sheet_name='CYTB', index=False)
    
    # Crear una DataFrame con toda la información de las secuencias únicas
    df_secuencias_final = pd.DataFrame.from_dict(info_secuencias, orient='index', columns=["ACCESSION", "SPECIES_NAME", "Synonims", "GENE", "SPECIMEN_VOUCHER", "COUNTRY", "STATE", "LOCALITY", "LATITUDE", "LONGITUDE", "NUM_BASES", "RELEASE_DATE", "BOLD_code"])

    df_secuencias_final.rename(columns={
        "ACCESSION": "GenBank Accession", 
        "SPECIES_NAME": "Species", 
        "GENE": "Locus", 
        "SPECIMEN_VOUCHER": "Specimen Voucher", 
        "COUNTRY": "Country", 
        "STATE": "Province/State", 
        "LOCALITY": "Locality", 
        "LATITUDE": "Latitude", 
        "LONGITUDE": "Longitude", 
        "NUM_BASES": "Num bp", 
        "RELEASE_DATE": "Collect Date", 
        "BOLD_code": "BOLD ID"
    }, inplace=True)
    
    # Guardar la DataFrame de secuencias únicas en un archivo Excel
    df_secuencias_final.to_excel("Genbank_rawdata.xlsx", index=False)
   
if __name__ == "__main__":
    tsn_orden = input("Please enter TSN number: ")
    main(tsn_orden)