# Comprobaciones comunes. La lista de textos prohibidos vive FUERA del repo (~/.config/dovexa/prohibido.txt).
OK_MAIL='^(plegasense@gmail\.com|[0-9]+\+plegasense@users\.noreply\.github\.com)$'
LISTA="$HOME/.config/dovexa/prohibido.txt"
fallo() { echo "BLOQUEADO: $1" >&2; exit 1; }
revisa_identidad() { # $1 nombre $2 correo
  [ "$1" = "plegasense" ] || fallo "autor '$1' (debe ser plegasense). Ejecuta: git config user.name plegasense"
  echo "$2" | grep -Eq "$OK_MAIL" || fallo "correo '$2' no permitido. Ejecuta: git config user.email plegasense@gmail.com"
}
revisa_texto() { # lee líneas añadidas por stdin
  [ -f "$LISTA" ] || return 0
  grep -E '^\+' | grep -Ev '^\+\+\+' | grep -Eif "$LISTA" >/dev/null && { echo "BLOQUEADO: el cambio contiene texto personal de la lista prohibida" >&2; return 1; }
  return 0
}
