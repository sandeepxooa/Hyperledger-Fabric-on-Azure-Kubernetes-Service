ARG GO_VERSION
ARG ALPINE_VERSION

FROM golang:${GO_VERSION}-alpine${ALPINE_VERSION} as golang
RUN apk add --no-cache \
	bash \
	gcc \
	git \
	make \
	musl-dev \
	tar \
	docker \
	curl

ARG FABRIC_VERSION
ARG FABRIC_CA_VERSION

RUN mkdir -p $GOPATH/src/github.com/hyperledger \
	&& git clone https://github.com/hyperledger/fabric.git --branch v${FABRIC_VERSION} \
		$GOPATH/src/github.com/hyperledger/fabric

RUN git clone https://github.com/hyperledger/fabric-ca.git --branch v${FABRIC_CA_VERSION} \
    $GOPATH/src/github.com/hyperledger/fabric-ca

##################################################################################################################################

FROM golang as hlf-builder

ARG GO_TAGS

RUN cd $GOPATH/src/github.com/hyperledger/fabric \
    && make configtxgen configtxlator cryptogen peer discover osnadmin idemixgen GO_TAGS=${GO_TAGS}


RUN cd $GOPATH/src/github.com/hyperledger/fabric-ca \
    && make fabric-ca-client

##################################################################################################################################

FROM golang:${GO_VERSION}-alpine${ALPINE_VERSION}


RUN apk add --no-cache \
	bash \
	git \
	jq \
	tzdata curl wget libc6-compat;


ARG GIT_COMMIT=unspecified
LABEL git_commit=$GIT_COMMIT

# Copy HLF dependecies from previous layer
ENV GOPATH /go
ARG FABRIC_PATH=$GOPATH/src/github.com/hyperledger

ENV FABRIC_CFG_PATH /etc/hyperledger/fabric

VOLUME /etc/hyperledger/fabric
COPY --from=hlf-builder /go/src/github.com/hyperledger/fabric/build/bin /usr/local/bin
COPY --from=hlf-builder /go/src/github.com/hyperledger/fabric/sampleconfig ${FABRIC_CFG_PATH}
COPY --from=hlf-builder $FABRIC_PATH/fabric-ca/bin/fabric-ca-client /usr/local/bin

# Kubernetes client
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/v1.15.5/bin/linux/amd64/kubectl
RUN chmod +x ./kubectl
RUN mv ./kubectl /usr/local/bin/kubectl

# Creating directories
RUN mkdir -p /var/hyperledger/deployments \
    && mkdir -p /var/hyperledger/scripts \
    && mkdir -p /var/hyperledger/consortiumScripts \
    && mkdir -p /var/hyperledger/src/chaincode

# Download azcopy
RUN wget https://aka.ms/downloadazcopy-v10-linux \
    && tar -xvf downloadazcopy-v10-linux \
    && cp ./azcopy_linux_amd64_*/azcopy /usr/bin/

# Download jq tool
RUN apk update \
    && apk add --no-cache jq openssl coreutils

# Copy AKS HLF artifacts
COPY ./fabricTools/deployments /var/hyperledger/deployments
COPY ./fabricTools/scripts /var/hyperledger/scripts

COPY ./consortiumScripts/scripts /var/hyperledger/consortiumScripts
COPY ./consortiumScripts/chaincode /var/hyperledger/src/chaincode

# Make the AKS HLF scripts executable
RUN chmod +x /var/hyperledger/scripts/*.sh
RUN chmod +x /var/hyperledger/consortiumScripts/*.sh

ENV OPENSSL_CONF=/var/hyperledger/scripts/openssl_root.cnf
