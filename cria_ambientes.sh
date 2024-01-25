#!/bin/bash

################################################################
# Load in the functions and animations                         #
source ./bash_loading_animations.sh                            #
# Run BLA::stop_loading_animation if the script is interrupted #
trap BLA::stop_loading_animation SIGINT                        #
################################################################

# Verifica entrada do usuário e se está requisitando o manual de ajuda
if [[ ( $@ == "--help" || $@ == "-h" ) ]]; then
  echo "Usage: Preencha os campos com os valores conforme forem sendo solicitados."
  exit 0
fi

# Define cores das letras
GREEN='\033[0;32m'
NC='\033[0m' # Sem cor

ambientes=( "dev" "teste" "hml" "prd" )
secrets=( "login-git" "quay-builder" )
GetPrj="oc get project"
NewPrj="oc new-project"

echo "Qual o nome do projeto?"

read -e proj

BLA::start_loading_animation "${BLA_braille_whitespace[@]}"
echo -e "\nVerificando se o projeto já existe" && sleep 3
BLA::stop_loading_animation &> /dev/null

# Executa comando para verificar os ambientes
for env in "${ambientes[@]}"; do
  if [[ $($GetPrj $env-$proj | awk '{print $2}' | tail -n1) == "Active" ]] &> /dev/null; then 
    echo -e "\nProjeto ${GREEN}$env-$proj${NC} já existe!"
  else [[ $($GetPrj $env-$proj | awk '{print $2}' | tail -n1) != "Active" ]] &> /dev/null
    echo -e "\nCriando Projeto ${GREEN}$env-$proj${NC}"
    $NewPrj $env-$proj &> /dev/null
    echo -e "\nCriando secret para login no repositório e no Quay no projeto ${GREEN}$env-$proj${NC}"
    kubectl get secret [nome do secret] -n [namespace] -o yaml | sed "s/namespace: .*/namespace: $env-$proj/" | oc apply -f -
    kubectl get secret [nome do secret] -n [namespace] -o yaml | sed "s/namespace: .*/namespace: $env-$proj/" | oc apply -f -
    # Linka o secret ao usuário builder para realizar o pull das imagens
    oc secrets link builder [nome do secret builder] -n $env-$proj      
fi
done

echo -e "O projeto precisa de volume persistente?"
read -e -n1 -p "Criar volume? [y,n]" CriaVolume

echo -e "\nInsira o nome do volume: "
read -e NomeVolume

echo -e "\nQual o tamanho do volume? Ex: 1Gi ou 100Mib"
read -e TamanhoVolume

for volume in "{$ambientes[@]}"; do
  if [[ $CriaVolume == 'Y' || $CriaVolume == 'y' ]]; then
    echo -e "\nCriando volume $NomeVolume para o projeto ${GREEN}$env-$proj${NC}"
    sed -i "s/NOME/$NomeVolume/" pv.yml
    sed -i "s/NAMESPACE/$env-$proj/" pv.yml
    sed -i "s/TAMANHO/$TamanhoVolume/" pv.yml
    oc apply -f pv.yml
  fi
done
