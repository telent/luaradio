plot(){
    gnuplot -geometry 1800x400  -e "set terminal x11; plot '< sox $1 -t s32 - ' binary format='%int32' using 0:1 with impulses; pause -1 'done'";
}
dump(){
    for i in `find /tmp/ -maxdepth 1 -name g0\*bin -size +1c |sort`;
    do
        echo "== $i";
        od -tx1 -Ax $i;
    done
}
process(){
    for i in ../rtl_433/g0*cu8;
    do
        ./luaradio finding-dore.lua $i;
    done 2>&1
}
