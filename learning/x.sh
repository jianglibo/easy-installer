if [ $1 ]
then
  epelInFile=$(grep origin $1)
  if [ $epelInFile ]
  then
    echo "found"
  else
    echo "not found"
  fi
else
  echo "no param"
fi
