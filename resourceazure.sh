#!/bin/bash
PS3='Choose your option: '
options=("Resource Group Create" "Resource Group Delete" "Storage Account Create" "Container Create" "Quit")
select opt in "${options[@]}"; do
    case $opt in
        "Resource Group Create")
            read -p 'Resource Group name:' rg
            read -p 'Resource Group Location:' rl
            az group create --name "$rg" --location "$rl"   
            sleep 8
            echo "Resource Group is created" 
            ;;
        "Resource Group Delete")
            read -p 'Resource Group name:' rg
            az group delete --name "$rg"  
            sleep 8
            echo "Resource Group is deleted" 
            ;;
        "Storage Account Create")
            read -p 'Storage Account name:' stg
            read -p 'Resource Group name:' rg
            read -p 'location' rl
            az storage account create -n "$stg" -g "$rg" --kind StorageV2 -l "$rl" --sku Standard_LRS
            sleep 8
            echo "Storage Account Created" 
            ;;
        "Container Create")
            read -p 'In which storage:' stg
            read -p 'In which Ressource group storage account exist:' rg
            read -p 'container name' cn
            az storage container create -n "$cn" --account-name "$stg" -g "$rg" --fail-on-exist
            sleep 8
            echo "Storage Blob Container Created" 
            ;;
        "Quit")
            break
            ;;
        *) echo "invalid option $REPLY";;
    esac
        counter=1
    SAVEIFS=$IFS
    IFS=$(echo -en "\n\b")
    for i in ${options[@]};
    do
        echo $counter')' $i
        let 'counter+=1'
    done
    IFS=$SAVEIFS
done