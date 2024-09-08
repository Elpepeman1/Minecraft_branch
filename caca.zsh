#!/bin/zsh


exec > >(tee -a output.log) 2>&1


remove_large_files_from_stage() {
    local max_size=100000000  


    for archivo in $(git diff --cached --name-only); do
        tamaño=$(stat -c %s "$archivo")
        if (( tamaño > max_size )); then
            echo "Archivo grande detectado en staging: $archivo"
            echo "Eliminando $archivo del staging..."
            git restore --staged "$archivo"
        fi
    done
}


force_push_filtered() {
    local branch_name=$1
    local commit=$2

    echo "Realizando push forzado en la rama $branch_name con archivos menores de 100 MB"
    git update-ref "refs/heads/$branch_name" $commit
    git push --force origin $branch_name 

    if [[ $? -ne 0 ]]; then
        echo "Error en el push forzado"
        exit 1
    fi

    echo "Push forzado realizado con éxito en la rama $branch_name."
}


update_branch() {
    echo "Obteniendo cambios del remoto..."
    git fetch origin

    echo "Fusionando cambios del remoto en la rama actual..."
    git merge --ff-only origin/$(git rev-parse --abbrev-ref HEAD)

    if [[ $? -ne 0 ]]; then
        echo "Error en la fusión de cambios del remoto"
        exit 1
    fi
}


branch() {
    cd "$(ls -d /workspaces/*/)" || exit

    new_branch_name="Minecraft_branch"
    excluded_files="excluded_files.txt"


    current_branch=$(git rev-parse --abbrev-ref HEAD)
    
    echo "Nombre de la rama actual: $current_branch"

    echo "Obteniendo la URL del repositorio remoto"
    git remote -v

    git rm -r --cached .
    git checkout -b $new_branch_name

    archivos_excluidos=()
    > "$excluded_files"

    for archivo in $(find servidor_minecraft -type f); do
        tamaño=$(stat -c %s "$archivo")
        if (( tamaño < 100 * 1024 * 1024 )); then
            git add --force "$archivo"
        else
            archivos_excluidos+=("$archivo")
            echo "$archivo" >> "$excluded_files"
        fi
    done

    for archivo in $(find addons -type f); do
        tamaño=$(stat -c %s "$archivo")
        if (( tamaño < 100 * 1024 * 1024 )); then
            git add --force "$archivo"
        else
            archivos_excluidos+=("$archivo")
            echo "$archivo" >> "$excluded_files"
        fi
    done

    configuracion_json='configuracion.json'
    tamaño=$(stat -c %s "$configuracion_json")
    if (( tamaño < 100 * 1024 * 1024 )); then 
        git add --force "$configuracion_json"
    else
        archivos_excluidos+=("$configuracion_json")
        echo "$configuracion_json" >> "$excluded_files"
    fi


    if (( ${#archivos_excluidos[@]} > 0 )); then
        echo "\nLos siguientes archivos no fueron añadidos al branch debido a que superan los 100MB:"
        for archivo in "${archivos_excluidos[@]}"; do
            echo "$archivo"
        done
    fi


    remove_large_files_from_stage


    update_branch


    commit_tree=$(git write-tree)
    commit_message="Branch para guardar tu server_minecraft"
    commit=$(git commit-tree $commit_tree -m "$commit_message")


    force_push_filtered $new_branch_name $commit

    git add -f "$excluded_files"
    git commit -m "Añadido excluded_files.txt con los archivos grandes excluidos"
    git push origin $new_branch_name
}


process_in_background() {

    echo "Esperando 10 minutos antes de la primera ejecución..."
    sleep 600 

    while true; do
        echo "Iniciando proceso de sincronización..."


        branch


        echo "Esperando 10 minutos antes de la próxima ejecución..."
        sleep 600  # 600 segundos = 10 minutos
    done
}


process_in_background &
