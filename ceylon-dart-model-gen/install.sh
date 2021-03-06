mkdir -p ~/.ceylon/repo/dart/async/1.3.0
mkdir -p ~/.ceylon/repo/dart/collection/1.3.0
mkdir -p ~/.ceylon/repo/dart/convert/1.3.0
mkdir -p ~/.ceylon/repo/dart/core/1.3.0
mkdir -p ~/.ceylon/repo/dart/developer/1.3.0
mkdir -p ~/.ceylon/repo/dart/io/1.3.0
mkdir -p ~/.ceylon/repo/dart/isolate/1.3.0
mkdir -p ~/.ceylon/repo/dart/math/1.3.0
mkdir -p ~/.ceylon/repo/dart/mirrors/1.3.0
mkdir -p ~/.ceylon/repo/dart/typed_data/1.3.0

cp -a modules/dart.async-1.3.0-dartmodel.json ~/.ceylon/repo/dart/async/1.3.0
cp -a modules/dart.collection-1.3.0-dartmodel.json ~/.ceylon/repo/dart/collection/1.3.0
cp -a modules/dart.convert-1.3.0-dartmodel.json ~/.ceylon/repo/dart/convert/1.3.0
cp -a modules/dart.core-1.3.0-dartmodel.json ~/.ceylon/repo/dart/core/1.3.0
cp -a modules/dart.developer-1.3.0-dartmodel.json ~/.ceylon/repo/dart/developer/1.3.0
cp -a modules/dart.io-1.3.0-dartmodel.json ~/.ceylon/repo/dart/io/1.3.0
cp -a modules/dart.isolate-1.3.0-dartmodel.json ~/.ceylon/repo/dart/isolate/1.3.0
cp -a modules/dart.math-1.3.0-dartmodel.json ~/.ceylon/repo/dart/math/1.3.0
cp -a modules/dart.mirrors-1.3.0-dartmodel.json ~/.ceylon/repo/dart/mirrors/1.3.0
cp -a modules/dart.typed_data-1.3.0-dartmodel.json ~/.ceylon/repo/dart/typed_data/1.3.0

touch ~/.ceylon/repo/dart/async/1.3.0/dart.async-1.3.0.dart
touch ~/.ceylon/repo/dart/collection/1.3.0/dart.collection-1.3.0.dart
touch ~/.ceylon/repo/dart/core/1.3.0/dart.core-1.3.0.dart
touch ~/.ceylon/repo/dart/developer/1.3.0/dart.developer-1.3.0.dart
touch ~/.ceylon/repo/dart/convert/1.3.0/dart.convert-1.3.0.dart
touch ~/.ceylon/repo/dart/io/1.3.0/dart.io-1.3.0.dart
touch ~/.ceylon/repo/dart/isolate/1.3.0/dart.isolate-1.3.0.dart
touch ~/.ceylon/repo/dart/math/1.3.0/dart.math-1.3.0.dart
touch ~/.ceylon/repo/dart/mirrors/1.3.0/dart.mirrors-1.3.0.dart
touch ~/.ceylon/repo/dart/typed_data/1.3.0/dart.typed_data-1.3.0.dart

rm -f ~/.ceylon/repo/dart/*/1.3.0/*sha1
