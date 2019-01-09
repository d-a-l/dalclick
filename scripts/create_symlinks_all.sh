#/bin/bash

if [ "$CREATE_SYMLINKS" == "Yes" ] || [ "$CREATE_SYMLINKS" == "Clear" ]
  then
   # delete symliks if any
   if find "$ALLPATH" -mindepth 1 -maxdepth 1 -print -quit | grep -q .
    then
      echo -n " Limpiando '$ALLPATH'.."
      find "$ALLPATH" -mindepth 1 -delete && echo "OK" || { echo " ERROR al intentar borrar symlinks de '$ALLPATH'"; exit 1; }
   else
      echo " Directorio '$ALLPATH' vacío"
   fi
fi

if [ "$CREATE_SYMLINKS" == "Yes" ]
 then
  # create symlinks from 'odd' and 'even' in 'all'
  # delete "test.jpg" (depreciated!)
  if [ "$NOCMODE" == 'odd-even' ]; then
    if find "$EVENPATH" -mindepth 1 -maxdepth 1 -name "test.jpg" | grep -q .
     then
      rm "$EVENPATH/test.jpg" &&
          echo " - se eliminó el archivo de prueba 'test.jpg' de '$EVENPATH'" ||
          { echo "Error: Debug 01"; exit 1; }
    fi
    if find "$ODDPATH" -mindepth 1 -maxdepth 1 -name "test.jpg" | grep -q .
     then
      rm "$ODDPATH/test.jpg" &&
          echo " - se eliminó el archivo de prueba 'test.jpg' de '$ODDPATH'" ||
          { echo "Error: Debug 02"; exit 1; }
    fi
  else # nocmode == 'single'
    if find "$SINGLEPATH" -mindepth 1 -maxdepth 1 -name "test.jpg" | grep -q .
     then
      rm "$SINGLEPATH/test.jpg" &&
          echo " - se eliminó el archivo de prueba 'test.jpg' de '$ODDPATH'" ||
          { echo "Error: Debug 02"; exit 1; }
    fi
  fi
  # create symlinks
  if  [ "$NOCMODE" == 'odd-even' ]; then
    echo -n " Creando symlinks en '$ALLPATH'.."
    find "$EVENPATH" -mindepth 1 -maxdepth 1 -type f -exec ln -s {} "$ALLPATH" \; &&
      echo -n "OK .." ||
      { echo " ERROR al intentar crear symlinks desde '$EVENPATH'"; exit 1; }
    find "$ODDPATH" -mindepth 1 -maxdepth 1 -type f -exec ln -s {} "$ALLPATH" \; &&
      echo " OK" ||
      { echo " ERROR al intentar crear symlinks desde '$ODDPATH'"; exit 1; }
  else # nocmode == 'single'
    echo -n " Creando symlinks en '$ALLPATH'.."
    find "$SINGLEPATH" -mindepth 1 -maxdepth 1 -type f -exec ln -s {} "$ALLPATH" \; &&
      echo -n "OK .." ||
      { echo " ERROR al intentar crear symlinks desde '$SINGLEPATH'"; exit 1; }
  fi
fi
