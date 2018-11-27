FROM alpine:3.8
RUN apk add --no-cache iproute2
ADD apply.sh /
ADD remove.sh /
ENTRYPOINT /apply.sh
