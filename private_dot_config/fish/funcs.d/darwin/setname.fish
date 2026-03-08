function setname -a newhostname
    sudo -v
    sudo scutil --set ComputerName $newhostname
    sudo scutil --set LocalHostName $newhostname
    sudo scutil --set HostName {$newhostname}.local
    dscacheutil -flushcache
end
