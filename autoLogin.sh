#!/bin/bash

#默认服务器配置项
#Alias         Name       port  IP  ssh-uer   ssh-password   ssh-key-path      su-root  su-password
CONFIGS=()

#基础目录
BaseDir="/etc/ssh_login"
#配置文件目录
CONFIG_PATH="$BaseDir/host.ini"

# 读取配置文件
if [ -f ${CONFIG_PATH} ]; then
    CONFIGS=()
    while read line
    do
        # 注释行或空行 跳过
        if [[ ${line:0:1} == "#" || $line =~ ^$ ]]; then
            continue
        else
            CONFIGS+=("$line")
        fi
    done < ${CONFIG_PATH}
fi

#服务器配置数
CONFIG_LENGTH=${#CONFIGS[*]}  #配置站点个数

##
# 检查基础目录是否存在
##
CheckDir()
{
    if [ ! -d "$BaseDir" ]; then
        mkdir -p $BaseDir
    fi
}

##
# 检查是否有配置信息
##
CheckConfig()
{
    if [[ $CONFIG_LENGTH -le 0 ]] ;
    then
        echo "未检测到服务器配置项!请使用 ssh_login -c 命令配置!"
        exit ;
    fi
}

##
# 绿色输出
##
function GreenEcho() {
    echo -e "\033[32m ${1} \033[0m";
}

##
# 服务器配置菜单
##
function ConfigList(){
    CheckConfig
    printf "%-8s %-15s %-15s %-5s %-10s %-10s\n" No  Alias Ip Port  Ssh-user Su-user
    #echo -e "- 序号\t\t别名\t\tIP\t\t\t\t端口\t\t登录用户\t\t切换用户名"
    for ((i=0;i<${CONFIG_LENGTH};i++));
    do
        CONFIG=(${CONFIGS[$i]}) #将一维sites字符串赋值到数组
        serverNum=$(($i+1))
        #echo -e "- [${serverNum}]\t\t${CONFIG[0]}\t\t${CONFIG[3]}\t\t\t${CONFIG[2]}\t\t${CONFIG[4]}\t\t${CONFIG[7]}"
    printf "%-8s|%-15s|%-15s|%-5s|%-10s|%-10s\n" ${serverNum} ${CONFIG[0]} ${CONFIG[3]} ${CONFIG[2]} ${CONFIG[4]} ${CONFIG[7]}
    done
}

##
# 登录菜单
##
function LoginMenu(){
    CheckConfig
    if [  ! -n $1 ]; then
        AutoLogin $1
    else
        echo "-------请输入登录的服务器/Alias/IP---------"
        ConfigList
        echo "请输入您选择登录的服务器/Alias/IP: "
    fi
}

##
# 选择登录的服务器
##
function ChooseServer(){
    read serverNum;

    # 是否重新选择
    needChooseServer=1;

    if [  -z $serverNum ]; then
        echo "请输入序号/Alias/IP"
        reChooseServer $needChooseServer;
    fi

    AutoLogin $serverNum $needChooseServer;
}

##
# 是退出还是重新选择Server
# @param $1 是否重新选择server 1: 重新选择server
##
function reChooseServer(){
    if [ "$1"x = "1"x ]; then
        ChooseServer;
    else
        exit;
    fi    
}

## 
# 自动登录
# @param $1 序号或者别名/ip
# @param $2 是否重新选择server 1: 重新选择server
##
function AutoLogin(){
    CheckConfig
    num=$(GetServer $1)
    if [  -z $num ]; then
        echo "您输入的Alias【$1】不存在，请重试"
        reChooseServer $2;
    fi

    CONFIG=(${CONFIGS[$num]})
    if [  -z $CONFIG ]; then
        echo "您输入的序号或ip地址【$1】不存在，请重试"
        reChooseServer $2;
    else
        echo "正在登录【${CONFIG[1]}】"
    fi
    export USER=${CONFIG[4]};
	export PASSWORD=${CONFIG[5]};
    export SUUSER=${CONFIG[7]};
    export SUPASSWORD=${CONFIG[8]};
    command="
        expect {
                \"*assword\" {set timeout 6000; send \$env(PASSWORD)\r; exp_continue ; sleep 3; }
                \"*passphrase\" {set timeout 6000; send \$env(PASSWORD)\n\r; exp_continue ; sleep 3; }
                \"yes/no\" {send \"yes\n\"; exp_continue;}
                \"Last*\" { send \"whoami\n\"; }
        }
       interact
    ";
   commandsu="
        expect {
                \"*assword\" {set timeout 6000; send \$env(PASSWORD)\r; exp_continue ; sleep 3; }
                \"*passphrase\" {set timeout 6000; send \$$env(PASSWORD)\n\r; exp_continue ; sleep 3; }
                \"yes/no\" {send \"yes\n\"; exp_continue ;}
                \"Last*\" {send \"su - \$env(SUUSER)\r\"; exp_continue ; sleep 3; }
                \"Password:\" {send \$env(SUPASSWORD)\n\r; exp_continue ;  }
                \"*~#*\" {send \"whoami\n\"; }
        }
       interact
    ";
    if [  "${CONFIG[7]}" != "NULL" ] ;then
        command=$commandsu
    fi    

    if [  "${CONFIG[6]}" != "NULL" ] ;then
           expect -c " 
              spawn ssh -p ${CONFIG[2]} -i ${CONFIG[6]} ${CONFIG[4]}@${CONFIG[3]}
              $command
           "      
    else
            expect -c "
              spawn ssh -p ${CONFIG[2]} ${CONFIG[4]}@${CONFIG[3]}
              $command
            "
    fi
    GreenEcho "您已退出【${CONFIG[1]}】"
    exit;

}

## 
# 通过输入定位选择那个服务器配置
##
function GetServer(){
    # 判断输入是否为数字
    if [ "$1" -gt 0 ] 2>/dev/null ;then
      echo $(($1-1))
    else
        for key in ${!CONFIGS[*]} ; do
            item=(${CONFIGS[$key]})
            if [ ${item[0]} == $1 ]; then
                echo $key
                return;
            fi
            if [ ${item[3]} == $1 ]; then
                echo $key
                return;
            fi
        done
    fi
}

##
# 帮助菜单
##
ShowHelp()
{
	echo 'Usage: ssh_login [OPTIONS]'
	echo
	echo 'OPTIONS:'
	echo "-h | --help : show help of tool"
	echo "-c | --config : edit the configure of ssh host"
	echo "-l | --list : list all of host info"
	echo "[a-zA-z0-9]* |  auto Login by alias name or numbers"
	echo
}

##
# 帮助菜单
##
EditConfig()
{
    CheckDir
    if [ ! -f "$CONFIG_PATH" ]; then
echo "" >  $CONFIG_PATH       
cat << EOF >$CONFIG_PATH
###################################################################################################################
#                                      SSH 自动登录服务器账号配置                                                 #
#                                                                                                                 #
#        1.每一行配置一个账号信息，需按照指定顺序配置账号每项。                                                   #
#        2.密码中含特殊字符请参照https://github.com/jiangxianli/SSHAutoLogin#%E7%89%B9%E6%AE%8A%E8%AF%B4%E6%98%8E #
#          中转换表对应修改。                                                                                     #
#        3.如遇使用问题，请在ISSUE中提交https://github.com/jiangxianli/SSHAutoLogin/issues                        #
#                                                                                                                 #
###################################################################################################################
#Alias         Name        port   IP                ssh-uer     ssh-password   ssh-key-path     su-root   su-password
aws            AWS         22     0.0.0.0           ubuntu      NULL           NULL             NULL      NULL
aly            asa         22     0.0.0.0           work        NULL           NULL             NULL      NULL
EOF
    fi
    vi $CONFIG_PATH
}


##
# 程序入口
##
case $1 in
    '-h' | '--help' )
        ShowHelp
        exit
        ;;
    '--config' | '-c' )
        EditConfig
        exit
        ;;
    '-l' | '--list' )
        ConfigList
        exit
        ;;
   [a-zA-z0-9]* )
        AutoLogin $1
        exit
        ;;
    * )
    LoginMenu
    ChooseServer $1
    exit
    ;;
esac
