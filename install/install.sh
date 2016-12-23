#!/bin/bash

return_fail()
{
    echo [~FAILER~]$*
    exit 1
}

add_log()
{
    echo $*
}

init_env()
{
    export LOGIN_USER=${USER}
    add_log "export LOGIN_USER=$LOGIN_USER"
    export RETURN_VAR
    export CURRENT_DIR=`pwd`
    export ROOT_DIR=${CURRENT_DIR}/..
    export VERSION_DIR=${ROOT_DIR}/version
    export CONFIG_DIR=${ROOT_DIR}/install
    add_log "export RETURN_VAR=$RETURN_VAR, CURRENT_DIR=$CURRENT_DIR, ROOT_DIR=$ROOT_DIR, VERSION_DIR=$VERSION_DIR, CONFIG_DIR=$CONFIG_DIR"
    chmod +x -R $CONFIG_DIR
    dos2unix $CONFIG_DIR/*
    [ ! -f "$CONFIG_DIR/install.ini" ] && return_fail "$CONFIG_DIR/install.ini is not exist, please check!"
    . $CONFIG_DIR/install.ini
    cat $CONFIG_DIR/install.ini
    get_path_owner "${INSTALL_DIR}"
    [ $? != 0 ] && return_fail "get path ${INSTALL_DIR} owner failed!"
    export INSTALL_USER=$RETURN_VAR
    export INSTALL_USER_HOME=`grep ${INSTALL_USER} /etc/passwd | head -1 | awk -F: '{print $6}'`
    export INSTALL_USER_ID=`grep ${INSTALL_USER} /etc/passwd | head -1 | awk -F: '{print $3}'`
    export INSTALL_USER_GROUP_ID=`grep ${INSTALL_USER} /etc/passwd | head -1 | awk -F: '{print $4}'`
    export INSTALL_USER_GROUP=`grep :${INSTALL_USER_GROUP_ID}: /etc/group | head -1 | awk -F: '{print $1}'`
    add_log "export INSTALL_USER=$INSTALL_USER, INSTALL_USER_HOME=$INSTALL_USER_HOME, INSTALL_USER_ID=$INSTALL_USER_ID, INSTALL_USER_GROUP_ID=$INSTALL_USER_GROUP_ID, INSTALL_USER_GROUP=$INSTALL_USER_GROUP"
}

get_path_owner()
{
    local path=$1
    local passwd_file=/etc/passwd
    local home_path
    local user
    RETURN_VAR="root"
   
    [ -z "${path}" ] && return 1
    [ ! -f "$passwd_file" ] && return 1
    
    while read line
    do
        home_path=`echo $line | awk -F: '{print $6}'`
        user=`echo $line | awk -F: '{print $1}'`
        if [[ "$path" == "${home_path}"* ]]
        then
            RETURN_VAR=$user
            break
        fi
    done <  $passwd_file
    return 0
}

expand_file_content()
{
    local file=$1
    
    [ -z "$file" ] && return_fail "expand file content get none file!"
    [ ! -f "$file" ] && return_fail "expand file content get file not exist!"
    echo "echo \"" > ${file}.tmp
    cat $file >> ${file}.tmp
    echo "\"" >> ${file}.tmp
    . ${file}.tmp > ${file}.tmp.bak
    sed '/^$/d' ${file}.tmp.bak > ${file}
    rm ${file}.tmp
    rm ${file}.tmp.bak
    echo "expand file content:"
    cat ${file}
}

kill_process_with_keyword()
{
    local keyword=$1
    local exclude_key=$2
    
    [ -z "$keyword" ] && return 0
    echo "these process will be killed"
    if [ ! -z "$exclude_key" ]
    then
        ps -ef | grep "$keyword" | grep -v "$exclude_key" | grep -v grep
        ps -ef | grep "$keyword" | grep -v "$exclude_key" | grep -v grep | awk '{print $2}' | xargs -I{} kill -9 {}
    else
        ps -ef | grep "$keyword" | grep -v grep
        ps -ef | grep "$keyword" | grep -v grep | awk '{print $2}' | xargs -I{} kill -9 {}
    fi
}

uninstall()
{
    local uninstall_file=""
    
    [ ! -d "${INSTALL_DIR}" ] && return 0
    [ -d "${INSTALL_DIR}/data" ] && rm -rf ${INSTALL_DIR}/data
    [ -f "${INSTALL_DIR}/interfaces" ] && rm ${INSTALL_DIR}/interfaces
    asesuite_path=`find ${INSTALL_DIR} -type d -name ASESuite | head -1`
    [ -z "${asesuite_path}" ] && return 0
    uninstall_file=`find ${asesuite_path} -name uninstall | head -1`
    if [ ! -z "${uninstall_file}" ] && [ -f "${uninstall_file}" ] 
    then
        add_log "unstall sybase; exec file ${uninstall_file}" 
        kill_process_with_keyword "RUN_${SERVER_NAME}"'\|'"${SYBASE_ASE}"
        chmod +x ${uninstall_file}
        ${CONFIG_DIR}/uninstall.sh ${uninstall_file}
    fi

}

env_check()
{
    [ "${INSTALL_DIR}" == "/" ] && return_fail "cont install at root /"
    
    [ ! -f "$VERSION_DIR/$VERSION_FILE_NAME" ] && return_fail "$VERSION_DIR/$VERSION_FILE_NAME is not exist, please check!"
    [ ! -f "$CONFIG_DIR/$RESPONSE_CFG_FILE_NAME" ] && return_fail "$CONFIG_DIR/$RESPONSE_CFG_FILE_NAME is not exist, please check!"
    [ ! -f "$CONFIG_DIR/$PROFILE_FILE_NAME" ] && return_fail "$CONFIG_DIR/$PROFILE_FILE_NAME is not exist, please check!"
    [ ! -f "$CONFIG_DIR/$SERVER_CFG_FILE_NAME" ] && return_fail "$CONFIG_DIR/$SERVER_CFG_FILE_NAME is not exist, please check!"
    [ ! -f "$CONFIG_DIR/$BAK_SERVER_CFG_FILE_NAME" ] && return_fail "$CONFIG_DIR/$BAK_SERVER_CFG_FILE_NAME is not exist, please check!"
    [ ! -f "$CONFIG_DIR/$CHARSET_CFG_FILE_NAME" ] && return_fail "$CONFIG_DIR/$CHARSET_CFG_FILE_NAME is not exist, please check!"
    
    sed '/^$/d' $CONFIG_DIR/install.ini > $CONFIG_DIR/install.ini.tmp
    while read line
    do
        result=`echo ${line} | awk -F= '{if($2 == ""){print "0"}else{print "1"}}'`
        [ "${result}" == "0" ] && return_fail "conf $CONFIG_DIR/install.ini has unmodify config ${line}"
    done <  $CONFIG_DIR/install.ini.tmp
    rm $CONFIG_DIR/install.ini.tmp
}

modify_conf()
{
    for i in $PROFILE_FILE_NAME $RESPONSE_CFG_FILE_NAME $SERVER_CFG_FILE_NAME $BAK_SERVER_CFG_FILE_NAME $CHARSET_CFG_FILE_NAME
    do
        add_log "expand_file_content $i"
        expand_file_content $i
    done
}

install()
{
    local setup_file=""
    
    cd $VERSION_DIR
    add_log "tar -axf $VERSION_DIR/$VERSION_FILE_NAME &>/dev/null"
    tar -axf "$VERSION_DIR/$VERSION_FILE_NAME" &>/dev/null
    setup_file=`find . -name setup.bin | head -1`
    [ -z "$setup_file" ] && return_fail "setup file is not exist, please check!"
    [ ! -f "$setup_file" ] && return_fail "$setup_file is not exist, please check!"
    add_log "$setup_file -f $CONFIG_DIR/$RESPONSE_CFG_FILE_NAME -i silent -DAGREE_TO_SAP_LICENSE=true -DRUN_SLIENT=true"
    $setup_file -f $CONFIG_DIR/$RESPONSE_CFG_FILE_NAME -i silent -DAGREE_TO_SAP_LICENSE=true -DRUN_SLIENT=true
    if [ $? != 0 ]
    then
        return_fail "sybase install failed!"
    fi
    add_log "sybase install successed!"
    chown ${INSTALL_USER}:${INSTALL_USER_GROUP} -R ${INSTALL_DIR}
    chmod 755 -R ${INSTALL_DIR}
    add_log "${INSTALL_DIR} permission changed!"
    cd $CURRENT_DIR

    add_log "modify profile"
    [ -f "$INSTALL_USER_HOME/.profile" ] && rm $INSTALL_USER_HOME/.profile
    cat $CONFIG_DIR/$PROFILE_FILE_NAME > $INSTALL_USER_HOME/.bash_profile
    chown ${INSTALL_USER}:${INSTALL_USER_GROUP} $INSTALL_USER_HOME/.bash_profile
    chmod 755 $INSTALL_USER_HOME/.bash_profile
    . $INSTALL_USER_HOME/.bash_profile
}

create_server()
{
    if [ "$INSTALL_USER" == root ] 
    then
        [ ! -e "$INSTALL_DIR/${SYBASE_ASE}/bin/srvbuildres" ] && return_fail "$INSTALL_DIR/${SYBASE_ASE}/bin/srvbuildres is not exist, please check!"
        add_log "su - ${INSTALL_USER} -c $INSTALL_DIR/${SYBASE_ASE}/bin/srvbuildres -r $CONFIG_DIR/$SERVER_CFG_FILE_NAME"
        su - ${INSTALL_USER} -c "$INSTALL_DIR/${SYBASE_ASE}/bin/srvbuildres -r $CONFIG_DIR/$SERVER_CFG_FILE_NAME"
        add_log "su - ${INSTALL_USER} -c $INSTALL_DIR/${SYBASE_ASE}/bin/srvbuildres -r $CONFIG_DIR/$BAK_SERVER_CFG_FILE_NAME"
        su - ${INSTALL_USER} -c "$INSTALL_DIR/${SYBASE_ASE}/bin/srvbuildres -r $CONFIG_DIR/$BAK_SERVER_CFG_FILE_NAME"

        [ ! -e "$INSTALL_DIR/${SYBASE_ASE}/bin/sqllocres" ] && return_fail "$INSTALL_DIR/${SYBASE_ASE}/bin/sqllocres is not exist, please check!"
        add_log "su - ${INSTALL_USER} -c $INSTALL_DIR/${SYBASE_ASE}/bin/sqllocres -r $CONFIG_DIR/$CHARSET_CFG_FILE_NAME"
        su - ${INSTALL_USER} -c "$INSTALL_DIR/${SYBASE_ASE}/bin/sqllocres -r $CONFIG_DIR/$CHARSET_CFG_FILE_NAME"

        [ ! -e "$INSTALL_DIR/${SYBASE_OCS}/scripts/lnsyblibs" ] && return_fail "$INSTALL_DIR/${SYBASE_OCS}/scripts/lnsyblibs is not exist, please check!"
        add_log "su - ${INSTALL_USER} -c $INSTALL_DIR/${SYBASE_OCS}/scripts/lnsyblibs create"
        su - ${INSTALL_USER} -c "$INSTALL_DIR/${SYBASE_OCS}/scripts/lnsyblibs create"
    else
        [ ! -e "$INSTALL_DIR/${SYBASE_ASE}/bin/srvbuildres" ] && return_fail "$INSTALL_DIR/${SYBASE_ASE}/bin/srvbuildres is not exist, please check!"
        add_log "$INSTALL_DIR/${SYBASE_ASE}/bin/srvbuildres -r $CONFIG_DIR/$SERVER_CFG_FILE_NAME"
        $INSTALL_DIR/${SYBASE_ASE}/bin/srvbuildres -r $CONFIG_DIR/$SERVER_CFG_FILE_NAME
        add_log "$INSTALL_DIR/${SYBASE_ASE}/bin/srvbuildres -r $CONFIG_DIR/$BAK_SERVER_CFG_FILE_NAME"
        $INSTALL_DIR/${SYBASE_ASE}/bin/srvbuildres -r $CONFIG_DIR/$BAK_SERVER_CFG_FILE_NAME

        [ ! -e "$INSTALL_DIR/${SYBASE_ASE}/bin/sqllocres" ] && return_fail "$INSTALL_DIR/${SYBASE_ASE}/bin/sqllocres is not exist, please check!"
        add_log "$INSTALL_DIR/${SYBASE_ASE}/bin/sqllocres -r $CONFIG_DIR/$CHARSET_CFG_FILE_NAME"
        $INSTALL_DIR/${SYBASE_ASE}/bin/sqllocres -r $CONFIG_DIR/$CHARSET_CFG_FILE_NAME

        [ ! -e "$INSTALL_DIR/${SYBASE_OCS}/scripts/lnsyblibs" ] && return_fail "$INSTALL_DIR/${SYBASE_OCS}/scripts/lnsyblibs is not exist, please check!"
        add_log "$INSTALL_DIR/${SYBASE_OCS}/scripts/lnsyblibs create"
        $INSTALL_DIR/${SYBASE_OCS}/scripts/lnsyblibs create
    fi
}

add_log "############################init environment###################################"
init_env $*
add_log "############################check environment###################################"
env_check
add_log "############################modify conf###################################"
modify_conf
add_log "############################uninstall sybase###################################"
uninstall
add_log "############################install sybase###################################"
install
add_log "############################create server###################################"
create_server
add_log "############################SUCCESS###################################"
