import pandas as pd
import numpy as np
import os

def calculate_iucn_score(status):
    """Calcula el puntaje según estado IUCN (25%)."""
    if pd.isna(status) or status == "" or status is None:
        return 3
    
    scores = {
        'CR': 7,
        'EN': 6,
        'VU': 5,
        'NT': 4,
        'DD': 4,  # We consider that Deficient Data are more worrying than LC and NE
        'LC': 3,
        'NE': 1
    }
    return scores.get(str(status).upper(), 3)

def calculate_area_loss_score(percentage):
    """Calcula el puntaje según pérdida de área idónea (25%)."""
    if pd.isna(percentage) or percentage == "" or percentage is None:
        return 3
    
    try:
        percentage = float(percentage)
        if percentage > 80: return 5
        elif percentage > 60: return 4
        elif percentage > 40: return 3
        elif percentage > 20: return 2
        else: return 1
    except (ValueError, TypeError):
        return 3

def calculate_eoo_score(eoo):
    """Calcula el puntaje según EOO (km²) (25%)."""
    if pd.isna(eoo) or eoo == "" or eoo is None:
        return 3
    
    try:
        eoo = float(eoo)
        if eoo < 100: return 5
        elif eoo < 5000: return 4
        elif eoo < 20000: return 3
        elif eoo < 50000: return 2
        else: return 1
    except (ValueError, TypeError):
        return 3

def calculate_human_footprint_score(overlap):
    """Calcula el puntaje según solapamiento con huella humana (25%)."""
    if pd.isna(overlap) or overlap == "" or overlap is None:
        return 3
    
    try:
        overlap = float(overlap)
        if overlap > 80: return 5
        elif overlap > 60: return 4
        elif overlap > 40: return 3
        elif overlap > 20: return 2
        else: return 1
    except (ValueError, TypeError):
        return 3

def save_dataframe_with_formatting(df, filename):
    """
    Guarda el DataFrame como CSV y HTML con formato adecuado.
    
    Args:
        df: DataFrame a guardar
        filename: Nombre base del archivo (sin extensión)
    """
    # Guardar como CSV normalmente
    df.to_csv(f"{filename}.csv", index=False)
    
    # Crear HTML con estilos incorporados
    html_content = """
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            table {
                border-collapse: collapse;
                width: 100%;
            }
            th, td {
                border: 1px solid #dddddd;
                text-align: left;
                padding: 8px;
            }
            th {
                font-weight: bold;
                background-color: #f2f2f2;
            }
            tr:nth-child(even) {
                background-color: #f9f9f9;
            }
            .max-value {
                color: red;
                font-weight: bold;
            }
        </style>
    </head>
    <body>
    """
    
    # Comenzar la tabla
    html_content += "<table>\n<thead>\n<tr>\n"
    
    # Agregar encabezados
    for col in df.columns:
        html_content += f"<th>{col}</th>\n"
    
    html_content += "</tr>\n</thead>\n<tbody>\n"
    
    # Para tablas de contribuciones, necesitamos resaltar el valor máximo en ciertas columnas
    contribution_cols = [col for col in df.columns if 'contribution' in col.lower()]
    
    # Agregar filas
    for _, row in df.iterrows():
        html_content += "<tr>\n"
        
        for col in df.columns:
            # Si es una columna de contribución, necesitamos verificar si es el máximo
            if contribution_cols and col in contribution_cols:
                # Encontrar el valor máximo entre todas las columnas de contribución para esta fila
                contrib_values = {}
                for contrib_col in contribution_cols:
                    try:
                        # Quitar el símbolo % y convertir a float
                        val_str = str(row[contrib_col]).replace('%', '').strip()
                        contrib_values[contrib_col] = float(val_str)
                    except:
                        contrib_values[contrib_col] = 0
                
                # Determinar si la columna actual tiene el valor máximo
                if contrib_values:
                    max_col = max(contrib_values, key=contrib_values.get)
                    if col == max_col:
                        html_content += f'<td class="max-value">{row[col]}</td>\n'
                    else:
                        html_content += f"<td>{row[col]}</td>\n"
                else:
                    html_content += f"<td>{row[col]}</td>\n"
            else:
                html_content += f"<td>{row[col]}</td>\n"
        
        html_content += "</tr>\n"
    
    # Cerrar la tabla y el HTML
    html_content += "</tbody>\n</table>\n</body>\n</html>"
    
    # Guardar el archivo HTML
    with open(f"{filename}.html", "w", encoding="utf-8") as f:
        f.write(html_content)

def prioritize_species(input_file="species_priority_data.csv", output_prefix="species_priority"):
    """Función principal de priorización con 4 factores de peso igual (25%)."""
    try:
        # Leer datos
        df = pd.read_csv(input_file, na_values=['NA', 'N/A', '', '#N/A', '#N/D', 'NULL', 'null', '-'])
        
        # Comprobar que existe la columna species_name, si no existe, buscar 'species'
        if 'species_name' not in df.columns and 'species' in df.columns:
            df['species_name'] = df['species']
        
        # Mapeo de nombres de columnas para normalización
        column_mapping = {
            'species_name': 'species_name',
            'iucn_status': 'iucn_status',
            'area_loss_ssp245': 'area_loss_ssp245',
            'area_loss_ssp585': 'area_loss_ssp585',
            'terrestrial_eoo': 'eoo',
            'human_footprint': 'human_footprint'
        }
        
        # Normalizar columnas existentes
        df_normalized = df.copy()
        for orig_col, new_col in column_mapping.items():
            if orig_col in df.columns:
                df_normalized[new_col] = df[orig_col]
        
        # Asegurar que todas las columnas necesarias existen
        for col in ['species_name', 'iucn_status', 'area_loss_ssp245', 'area_loss_ssp585', 'eoo', 'human_footprint']:
            if col not in df_normalized.columns:
                df_normalized[col] = np.nan
        
        # PROCESO PARA SSP245
        df_ssp245 = df_normalized.copy()
        
        # Calcular todos los scores
        df_ssp245['iucn_score'] = df_ssp245['iucn_status'].apply(calculate_iucn_score)
        df_ssp245['area_loss_score'] = df_ssp245['area_loss_ssp245'].apply(calculate_area_loss_score)
        df_ssp245['eoo_score'] = df_ssp245['eoo'].apply(calculate_eoo_score)
        df_ssp245['human_footprint_score'] = df_ssp245['human_footprint'].apply(calculate_human_footprint_score)
        
        # Calcular contribuciones absolutas con pesos iguales (25%)
        df_ssp245['iucn_contribution_abs'] = df_ssp245['iucn_score'] * 0.25
        df_ssp245['area_loss_contribution_abs'] = df_ssp245['area_loss_score'] * 0.25
        df_ssp245['eoo_contribution_abs'] = df_ssp245['eoo_score'] * 0.25
        df_ssp245['human_footprint_contribution_abs'] = df_ssp245['human_footprint_score'] * 0.25
        
        # Puntaje final
        df_ssp245['final_score'] = (
            df_ssp245['iucn_contribution_abs'] +
            df_ssp245['area_loss_contribution_abs'] +
            df_ssp245['eoo_contribution_abs'] +
            df_ssp245['human_footprint_contribution_abs']
        )
        
        # Contribuciones relativas (porcentajes)
        for criterion in ['iucn', 'area_loss', 'eoo', 'human_footprint']:
            df_ssp245[f'{criterion}_contribution'] = (
                (df_ssp245[f'{criterion}_contribution_abs'] / df_ssp245['final_score'] * 100)
                .round(2)
                .astype(str) + '%'
            )
        
        # PROCESO PARA SSP585
        df_ssp585 = df_normalized.copy()
        
        # Calcular todos los scores
        df_ssp585['iucn_score'] = df_ssp585['iucn_status'].apply(calculate_iucn_score)
        df_ssp585['area_loss_score'] = df_ssp585['area_loss_ssp585'].apply(calculate_area_loss_score)
        df_ssp585['eoo_score'] = df_ssp585['eoo'].apply(calculate_eoo_score)
        df_ssp585['human_footprint_score'] = df_ssp585['human_footprint'].apply(calculate_human_footprint_score)
        
        # Calcular contribuciones absolutas con pesos iguales (25%)
        df_ssp585['iucn_contribution_abs'] = df_ssp585['iucn_score'] * 0.25
        df_ssp585['area_loss_contribution_abs'] = df_ssp585['area_loss_score'] * 0.25
        df_ssp585['eoo_contribution_abs'] = df_ssp585['eoo_score'] * 0.25
        df_ssp585['human_footprint_contribution_abs'] = df_ssp585['human_footprint_score'] * 0.25
        
        # Puntaje final
        df_ssp585['final_score'] = (
            df_ssp585['iucn_contribution_abs'] +
            df_ssp585['area_loss_contribution_abs'] +
            df_ssp585['eoo_contribution_abs'] +
            df_ssp585['human_footprint_contribution_abs']
        )
        
        # Contribuciones relativas (porcentajes)
        for criterion in ['iucn', 'area_loss', 'eoo', 'human_footprint']:
            df_ssp585[f'{criterion}_contribution'] = (
                (df_ssp585[f'{criterion}_contribution_abs'] / df_ssp585['final_score'] * 100)
                .round(2)
                .astype(str) + '%'
            )
        
        # Añadir categoría de prioridad
        for df_scenario in [df_ssp245, df_ssp585]:
            try:
                df_scenario['priority_category'] = pd.qcut(
                    df_scenario['final_score'], 
                    q=5, 
                    labels=['Muy baja', 'Baja', 'Media', 'Alta', 'Muy alta']
                )
            except:
                # Alternativa si hay muchos valores duplicados
                df_scenario['priority_category'] = pd.cut(
                    df_scenario['final_score'],
                    bins=5,
                    labels=['Muy baja', 'Baja', 'Media', 'Alta', 'Muy alta']
                )
        
        # Ordenar por puntaje final
        df_ssp245_sorted = df_ssp245.sort_values('final_score', ascending=False).reset_index(drop=True)
        df_ssp585_sorted = df_ssp585.sort_values('final_score', ascending=False).reset_index(drop=True)
        
        # Preparar tablas finales de resultados (CORREGIDO)
        results_ssp245 = df_ssp245_sorted[['species_name', 'iucn_status', 'area_loss_ssp245', 
                                          'eoo', 'human_footprint', 
                                          'final_score', 'priority_category']].copy()
        
        results_ssp585 = df_ssp585_sorted[['species_name', 'iucn_status', 'area_loss_ssp585', 
                                          'eoo', 'human_footprint', 
                                          'final_score', 'priority_category']].copy()
        
        # Renombrar columnas DESPUÉS de seleccionar
        results_ssp245 = results_ssp245.rename(columns={
            'species_name': 'species',
            'area_loss_ssp245': 'area_loss (%) ssp245',
            'eoo': 'terrestrial eoo (km2)',
            'human_footprint': 'human_footprint (%)'
        })
        
        results_ssp585 = results_ssp585.rename(columns={
            'species_name': 'species',
            'area_loss_ssp585': 'area_loss (%) ssp585',
            'eoo': 'terrestrial eoo (km2)',
            'human_footprint': 'human_footprint (%)'
        })
        
        # Tablas de contribuciones
        contributions_ssp245 = pd.DataFrame({
            'species name': df_ssp245_sorted['species_name'],
            'iucn contribution': df_ssp245_sorted['iucn_contribution'],
            'area loss contribution': df_ssp245_sorted['area_loss_contribution'],
            'terrestrial eoo (km2) contribution': df_ssp245_sorted['eoo_contribution'],
            'human footprint contribution': df_ssp245_sorted['human_footprint_contribution']
        })
        
        contributions_ssp585 = pd.DataFrame({
            'species name': df_ssp585_sorted['species_name'],
            'iucn contribution': df_ssp585_sorted['iucn_contribution'],
            'area loss contribution': df_ssp585_sorted['area_loss_contribution'],
            'terrestrial eoo (km2) contribution': df_ssp585_sorted['eoo_contribution'],
            'human footprint contribution': df_ssp585_sorted['human_footprint_contribution']
        })
        
        # Tabla de comparación entre escenarios (CORREGIDO)
        # Crear un merge basado en species_name para mantener la correspondencia
        comparison_base = df_normalized[['species_name']].copy()
        
        # Agregar scores de ambos escenarios
        comparison_base = comparison_base.merge(
            df_ssp245[['species_name', 'final_score', 'priority_category']].rename(columns={
                'final_score': 'score_ssp245',
                'priority_category': 'category_ssp245'
            }),
            on='species_name',
            how='left'
        )
        
        comparison_base = comparison_base.merge(
            df_ssp585[['species_name', 'final_score', 'priority_category']].rename(columns={
                'final_score': 'score_ssp585',
                'priority_category': 'category_ssp585'
            }),
            on='species_name',
            how='left'
        )
        
        # Calcular diferencia
        comparison_base['score_difference'] = comparison_base['score_ssp585'] - comparison_base['score_ssp245']
        
        # Renombrar columna de especies y ordenar
        comparison_df = comparison_base.rename(columns={'species_name': 'species'})
        comparison_df = comparison_df.sort_values('score_difference', ascending=False).reset_index(drop=True)
        
        # Crear tabla de cambios de ranking (CORREGIDO)
        df_ssp245_sorted['rank_ssp245'] = range(1, len(df_ssp245_sorted) + 1)
        df_ssp585_sorted['rank_ssp585'] = range(1, len(df_ssp585_sorted) + 1)
        
        # Merge para mantener correspondencia de especies
        rank_base = df_normalized[['species_name']].copy()
        
        rank_base = rank_base.merge(
            df_ssp245_sorted[['species_name', 'rank_ssp245', 'priority_category']].rename(columns={
                'priority_category': 'category_ssp245'
            }),
            on='species_name',
            how='left'
        )
        
        rank_base = rank_base.merge(
            df_ssp585_sorted[['species_name', 'rank_ssp585', 'priority_category']].rename(columns={
                'priority_category': 'category_ssp585'
            }),
            on='species_name',
            how='left'
        )
        
        # Calcular cambio de ranking
        rank_base['rank_change'] = rank_base['rank_ssp245'] - rank_base['rank_ssp585']
        
        # Renombrar y ordenar
        rank_comparison = rank_base.rename(columns={'species_name': 'species'})
        rank_comparison = rank_comparison.sort_values('rank_change', ascending=False, na_position='last').reset_index(drop=True)
        
        # Guardar resultados con formato
        save_dataframe_with_formatting(results_ssp245, f"{output_prefix}_ssp245")
        save_dataframe_with_formatting(results_ssp585, f"{output_prefix}_ssp585")
        save_dataframe_with_formatting(contributions_ssp245, f"{output_prefix}_contributions_ssp245")
        save_dataframe_with_formatting(contributions_ssp585, f"{output_prefix}_contributions_ssp585")
        save_dataframe_with_formatting(comparison_df, f"{output_prefix}_comparison")
        save_dataframe_with_formatting(rank_comparison, f"{output_prefix}_rank_changes")
        
        # Generar informe de datos faltantes
        na_report = pd.DataFrame({
            'species': df_normalized['species_name'],
            'iucn_missing': df_normalized['iucn_status'].isna(),
            'area_loss_ssp245_missing': df_normalized['area_loss_ssp245'].isna(),
            'area_loss_ssp585_missing': df_normalized['area_loss_ssp585'].isna(),
            'eoo_missing': df_normalized['eoo'].isna(),
            'human_footprint_missing': df_normalized['human_footprint'].isna(),
            'total_missing': df_normalized[['iucn_status', 'area_loss_ssp245', 'area_loss_ssp585', 
                                          'eoo', 'human_footprint']].isna().sum(axis=1)
        }).sort_values('total_missing', ascending=False)
        
        save_dataframe_with_formatting(na_report, f"{output_prefix}_missing_data_report")
        
        print(f"\nArchivos generados:")
        for ext in ['csv', 'html']:
            for file in [f"{output_prefix}_ssp245", 
                        f"{output_prefix}_ssp585", 
                        f"{output_prefix}_contributions_ssp245", 
                        f"{output_prefix}_contributions_ssp585",
                        f"{output_prefix}_comparison",
                        f"{output_prefix}_rank_changes",
                        f"{output_prefix}_missing_data_report"]:
                filepath = f"{file}.{ext}"
                if os.path.exists(filepath):
                    print(f"- {filepath}")
        
        print("\nIMPORTANTE: Para ver el formato correcto (negrita y colores), abra los archivos HTML con un navegador.")
        
        return results_ssp245, results_ssp585, contributions_ssp245, contributions_ssp585, comparison_df, rank_comparison
    
    except Exception as e:
        print(f"\nError al procesar los datos: {e}")
        import traceback
        print(traceback.format_exc())
        return None, None, None, None, None, None

# Ejecutar si se corre directamente
if __name__ == "__main__":
    try:
        results = prioritize_species()
        if results[0] is not None:
            print("\nProceso completado con éxito.")
    except Exception as e:
        print(f"\nError al ejecutar el programa: {e}")
        import traceback
        print(traceback.format_exc())