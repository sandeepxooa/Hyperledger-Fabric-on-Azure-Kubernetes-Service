artifactsFolder=out
rootFolder="$(dirname `pwd`)"

dockerfileLocation="fabricTools/fabricTools.dockerfile"
pushd $rootFolder
docker build . -f ${dockerfileLocation} -t $1 \
    --build-arg GO_VERSION=1.14 \
    --build-arg ALPINE_VERSION=3.13 \
    --build-arg FABRIC_VERSION=2.3.1 \
    --build-arg FABRIC_CA_VERSION=1.4.9
popd

artifactsFolder=${rootFolder}/${artifactsFolder}

if [[ -d $artifactsFolder ]]
then
    rm -rf $artifactsFolder
fi

mkdir $artifactsFolder
mkdir "${artifactsFolder}/nestedtemplates"
mkdir "${artifactsFolder}/artifacts"

publicIpTemplatePath="nestedtemplates/publicIpTemplate.json"

funcNodeJSFolder="$rootFolder/funcNodeJS"
funcNodeJSPath="$funcNodeJSFolder"
createUiDef="$rootFolder/createUiDefinition.json"
mainTemplate="$rootFolder/mainTemplate.json"
publicIpTemplate="$rootFolder/$publicIpTemplatePath"

nodeJsArchivePath="${artifactsFolder}/artifacts/funcNodeJS.zip"

pushd $funcNodeJSFolder
podJsonLocation=aksManifests/fabricTools/pod.json
cp $podJsonLocation "${podJsonLocation}_backup"
gsed -i 's|fabricToolsImageWithTag|'"$1"'|g' $podJsonLocation
npm ci
zip -r $nodeJsArchivePath *
mv "${podJsonLocation}_backup" $podJsonLocation
popd

cp $publicIpTemplate "$artifactsFolder/$publicIpTemplatePath"
cp $createUiDef $artifactsFolder
cp $mainTemplate $artifactsFolder

pushd $artifactsFolder

if [ ! -d "artifacts" ]
then
    echo "artifacts directory not present! Exiting.."
    exit 1
fi

if [ ! -d "nestedtemplates" ]
then
    echo "nestedtemplates directory not present! Exiting.."
    exit 1
fi

if [ ! -f "mainTemplate.json" ]
then
    echo "mainTemplate.json is not present! Exiting.."
    exit 1
fi

if [ ! -f "createUiDefinition.json" ]
then
    echo "createUiDefinition.json is not present! Exiting.."
    exit 1
fi

zip -r "${artifactsFolder}/hlf-marketplace.zip" *
popd
