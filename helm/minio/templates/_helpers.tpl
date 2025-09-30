{{- define "minio.name" -}}
{{ .Chart.Name }}
{{- end -}}

{{- define "minio.fullname" -}}
{{ printf "%s-%s" .Release.Name (include "minio.name" .) | trunc 63 | trimSuffix "-" }}
{{- end -}}

