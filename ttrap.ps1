trap {
    "Other terminating error trapped"
    $Error[0] | gm
}
trap [System.Management.Automation.CommandNotFoundException]
    {"Command error trapped"}

throw "abc"
