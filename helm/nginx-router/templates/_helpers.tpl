{{- define "nginx-router.name" -}}
{{ .Chart.Name }}
{{- end -}}

{{- define "nginx-router.fullname" -}}
{{ printf "%s-%s" .Release.Name (include "nginx-router.name" .) | trunc 63 | trimSuffix "-" }}
{{- end -}}

