{ pkgs }:
pkgs.runCommand "aibox-test-certificates" { nativeBuildInputs = [ pkgs.openssl ]; } ''
  mkdir -p "$out"
  openssl req -x509 -newkey rsa:2048 -nodes -days 36500 \
    -subj /CN=aibox-test-ca -keyout "$out/ca.key" -out "$out/ca.pem"
  openssl req -newkey rsa:2048 -nodes -subj /CN=localhost \
    -keyout "$out/server.key" -out server.csr
  printf 'subjectAltName=DNS:localhost,IP:127.0.0.1\n' > extensions
  openssl x509 -req -in server.csr -CA "$out/ca.pem" -CAkey "$out/ca.key" \
    -CAcreateserial -days 36500 -extfile extensions -out "$out/server.pem"
  openssl req -x509 -newkey rsa:2048 -nodes -days 36500 \
    -subj /CN=aibox-untrusted-ca -keyout unrelated.key -out "$out/untrusted.pem"
''
