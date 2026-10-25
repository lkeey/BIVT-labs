FROM golang:1.25-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY *.go ./
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/coursework-api .

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/coursework-api /coursework-api
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/coursework-api"]
