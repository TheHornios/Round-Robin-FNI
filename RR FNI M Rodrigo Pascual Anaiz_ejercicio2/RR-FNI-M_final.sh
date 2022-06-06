#!/bin/bash
# LAST_CHANGE 20171114_1800
# VERSION 0.4.66
###############################################################################################################################################################
# Script realizado por Mario Juez Gil. Sistemas Operativos, Grado en ingeniería informática UBU 2012-2013 						      #
#                                                                                                                                                             #
# Funcionamiento del script:                                                                                                                                  #
#	Parte importante del script se basa en la comprobación de las lecturas, especial importancia tienen:                                                 #
#		- Lectura de quantum 			 -> Deberá ser entero y mayor que 0                                                                  #
#		- Lectura del número de procesos -> Deberá ser entero y mayor que 0                                                                         #
#		- Lectura de ráfagas			 -> Deberán ser enteras y mayores que 0                                                              #
#		- Lectura de momento de E/S 	 -> Deberá ser desde 1 hasta la ráfaga total - 1 (E/S en el primer o último momento no tiene sentido)      #
#		- Lectura de duración E/S 		 -> Deberá ser entero y mayor que 0                                                                  #
#                                                                                                                                                             #
#	El script deberá contemplar la opción de Round Robin (Sin E/S), y Round Robin Virtual (Con E/S)                                                     #
#	Se usará el mismo algoritmo para ambos casos, ya que en RRV se puede dar el caso de que el proceso no tenga situación de E/S                        #
#	Para resolver el problema he usado los Arrays de bash:                                                                                                #
#		PROCESOS[indice] 	-> Almacena la ráfaga del proceso                                                                                    #
#		QT_PROC[indice]	 	-> Almacena el quantum sin usar del proceso (útil cuando un proceso se bloquea por E/S)                              #
#		PROC_ENAUX[indice] 	-> [ Si / No ] Nos dice si el proceso actual está en la cola auxiliar (bloqueado por E/S)                            #
#		T_ENTRADA[indice]	-> Tiempo de llegada en el sistema del proceso                                                                        #
#		EN_ESPERA[indice]	-> [ Si / No ] Proceso en espera por tiempo de llegada                                                                #
#		MOMENTO[indice]		-> Momento en el cual el proceso se bloqueará por una situación de E/S (solo RRV)                                    #
#		PART[indice]		-> 0..Num proc-1: Almacena -1 si no está asignada en ninguna partición o >=0 para la partcion con este indice 
#		DURACION[indice]	-> Duración de la situación de E/S (solo RRV)                                                                                 #
#		FIN_ES[indice]		-> Almacena cuando va a terminar la E/S de un proceso, teniendo en cuenta su posicion en la cola FIFO                 #
#		AUX[indice]			-> Cola FIFO auxiliar para los procesos bloqueados por E/S. Almacena indices de procesos.                 #
#		ENTRADA_SALIDA[indice] -> Para el caso de RRV indica "Si" si es proc de E/S y "No" si no lo es
#		PART_SIZE[indice]	-> Memoria total que tiene cada particion de memoria
#		COLORS[indice] 		-> Colores varios (codigo de shell para echo)
#		PROC_COLORS[indice] -> 0..Num proc-1: Colores de cada proceso (cada indice es el numero de proceso al que hace referencia - 1)
#		PROC_ELEGIDOS[indice]-> 0..Num proc-1: -1: Este proceso no es plausible a ser ejecutado. >0 puede ser ejecutado
#		TIEMPO_EJEC[indice]	-> 0..Num proc-1: Dice los instantes que ha estado en ejecucion
#		TIEMPO_PARADO[indice] -> 0..Num proc-1: Dice los instantes que ha estado En Memoria, En  Pauisa o En Buffer cada proceso
#		TIEMPO_FIN[indice]	-> 0..Num proc-1: Almacena los instantes que cada proceso ha finalizado su ejecucion
#		ESTADOS_ANTERIORES[indice] -> 0..Num proc -1: Lista con los estados que habia en anterioridad, para ver si se ha producido un cambio de estado en la ejecucion
#		gl_procesos_termiandos -> Lleva la cuenta de cuantos procesos estan en estado terminado para saber si el algoritmo principal debe terminar
#		proc_elegido 		 -> 0: No se puede ejecutar ningun proceso en el estado actual. >0 num de proceso que se puede ejecutar 
#		proc_min_rr			-> Es el proceso de la ventana del RR que marca el limite inferior que sepuede ejecutar
#		proc_max_rr			-> Marca como limite superior de la ventana RR el proceso que se puede ejecutar
#		proc_rr 			-> -1: Ninguno, >=0 es el ultimo proceso que se ejecuto dentro de la ventana del RR
#		gl_nuevo_puntero	-> 0: proc_rr no se ha movido en su último cálculo, 1: Ha cambiado de proceso debido a rotacion del RR
#		debug 				-> Se usa para debugar en modo antiguo, con muchisima informacion, se establece con argumento -d
# 		debug2				-> Se usa para debugar en modo mas amigable, con informacion bonita, se establede con argumento -d2
# 		gl_uno_ha_terminado -> Su usa para saber si en una iteracion un proceso acaba de terminar y debe refrescarse las particiones de memoria
#		gl_debug			-> Se pone a 1 si debug o debug2 son 1 (uno de ellos o los 2), sino es 0
#		gl_ajuste			-> Tipo de algoritmo de ajuste de memoria. 'fa': Primer ajuste, 'ba': Mejor ajuste, 'wa': Peor ajuste
#		gl_en_memoria		-> 0: Ningun proceso está asignado a una particion de memoria, 1: Alguno lo está
#		gl_alguno_en_ejecucion -> 0: Ningun proceso está ejecutándose, >0: Numero de procesos en ejecucion (solo puede ser uno máximo)
#		gl_nueva_reasignacion	-> Se utiliza para refrescar el puntero de la ventana del RR, si hay nueva reasignacion debe volver al primero de la nueva ventana calculada
#		gl_fuerza_iteracion_instante -> Se utiliza para debugar, lleva el programa a la iteracion que le indiquemos sin tener que tocar intros (-1 para desactivar)
#		gl_medio_quantum	-> 0: El tiempo transcurrido corresponde a la ejecucion de un quanum, 1: Estamos en un instante entre medio de un quantum
#		gl_quantum_restante -> Indica los instantes de quantum que quedan pendientes de ejecutar, por si tiene que fraccionar el quantum en varios procesos
#		gl_incr_tiempo		-> Marca cada cuanto tiempo se ejecuta una iteracion del RR, puede ser 1 o habitualmente el valor de $quantum
#		gl_primera_vez		-> Sirve para el algoritmo, para saber si es la primera iteracion o cualquie otra, ya que la primera vez es un caso especial para imprimir la tabla de ejecucion
#		gl_iteracion 		-> Se usa para debugar, dice en el bucle principal del algorimo en que iteracion estamos (Default 0)
#		gl_uno_en_ejecucion	-> Controla si existe algun proceso que esta en ejecucion (0 o 1)
#		gl_primero_en_ejecucion -> -1: No hay ninguno en ejecuion >=0 es el indice de proceso que se encuentra en estado de ejecucion
#		gl_quedan_procesos_anteriores -> Controla si a pesar de una ventana de ejecucion calculada, queda algun proceso rezagado anterior sin ejecutar
#		gl_proc_ejec		-> Controla el proceso que esta actualmente en ejecucion (-1: ninguno, >=0 el indice de proceso)
#		gl_tiempo_restar	-> Indica cuanto tiempo se resta en cada iteracion
#		gl_resta_por_quantum -> Indica si la resta de rafaga se hara por quanto (1) o bien por unidad de tiempo en gl_tiempo_restar (1)
# 		gl_cambio_de_estado -> Indica que algun proceso de toda la lista ha sufrido un cambio de estado (se usa para evitar repetir tablas imprimidas)
#		gl_cambio_proceso	-> Indica si ha habido cambio de proceso en ejecucion desde la anterior iteracion, util para dibujar la barra de historial de ejecucion de la parte inferior
#		gl_no_saltos -> Se activa a 1 cuando está por argumenot -ns para evitar que haga saltos de ejecucion el algoritmo
#		gl_color -> Por defecto a 0, sirve para decir si por el argumento (-c), el informe final (informe.txt) se abrirá en modo monocromo (con gedit) o con un cat para que se vea en color la salida
###############################################################################################################################################################


echo "############################################################"
echo "#                     Creative Commons                     #"
echo "#                                                          #"
echo "#                   BY - Atribución (BY)                   #"
echo "#                 NC - No uso Comercial (NC)               #"
echo "#                SA - Compartir Igual (SA)                 #"
echo "############################################################"

echo "############################################################" >> informeRR.txt
echo "#                     Creative Commons                     #" >> informeRR.txt
echo "#                                                          #" >> informeRR.txt
echo "#                   BY - Atribución (BY)                   #" >> informeRR.txt
echo "#                 NC - No uso Comercial (NC)               #" >> informeRR.txt
echo "#                SA - Compartir Igual (SA)                 #" >> informeRR.txt
echo "############################################################" >> informeRR.txt
echo "############################################################" >> informeColor.txt
echo "#                     Creative Commons                     #" >> informeColor.txt
echo "#                                                          #" >> informeColor.txt
echo "#                   BY - Atribución (BY)                   #" >> informeColor.txt
echo "#                 NC - No uso Comercial (NC)               #" >> informeColor.txt
echo "#                SA - Compartir Igual (SA)                 #" >> informeColor.txt
echo "############################################################" >> informeColor.txt


#Variables globales
opcion=0
tiempo_espera_algoritmo_automatico=1
min=9999
tamano=();
tamanoPartBarra=0;
debug=0
fich_modo_debug="ultimosRR" # Este es el nombre de fichero (sin la extension!!) que se ejecutara de forma directa en caso de que el argumenot -d esté activo
fich_random_cfg="ultimaRandomRR.cfg"
debug2=0
debug3=0
gl_debug=0
asignada=0
iter=0
gl_ajuste="ba"
proc_min_rr=0
proc_max_rr=0
proc_rr=-1
gl_nuevo_puntero=0 # Se usa para saber si se ha refrescado el cambio del puneto en la ventana (esto es que ha cambiado proc_rr de valor)
gl_en_memoria=0
gl_alguno_en_ejecucion=0 # Sirve para saber si hay alguno en ejecucion en un momento dado (o más de uno, que seria un error)
gl_nueva_reasignacion=0
gl_nueva_asignacion=0 # Se usa para saber si ha entrado algun proceso nuevo en memoria
gl_fuerza_iteracion_instante=-1
gl_primero=-1
gl_asignado=-1
gl_medio_quantum=0
gl_incr_tiempo=1
gl_primera_vez=1
gl_iteracion=0
gl_uno_en_ejecucion=0
gl_primero_en_ejecucion=-1
gl_uno_ha_terminado=0
gl_quedan_procesos_anteriores=0
gl_proc_ejec=-1
gl_tiempo_restar=1
gl_resta_por_quantum=0
gl_cambio_ejecucion=1
gl_array_tiempos=();
gl_cambio_de_estado=1 # Valor por defecto, asumimos que ha habido cambio de estado al inicio para que imprima la tabla la primera vez
gl_cambio_proceso=1 # Valor por defecto, asumimos que ha habido cambio de proceso de ejecucion al inicio para que así imprima el primer instante (0)
gl_ultimo_proceso_ejecucion=-1 # Valor por defecto, >0 indica el ultimo proceso que se ejecuto, imprescindible para actualizar la variable gl_cambio_proceso
gl_no_saltos=0 # Valor por defecto, es decir, que el algoritmo hara saltos en la impresion de la tabla en caso de que no haya cambios de estado
gl_color=0 # Varlor por defecto, se cambia a 1 con el argumento -c
gl_tiempo_muerto=0
no_duplicar_tabla=0 #bandera para no imprimir dos veces el histórico de ejecución.
max_ejecuciones=0
c_barra=0 #contador global para el vector de la barra de tiempo
contadorGAP=0 # bandera que permite poner el tiempo en la barra cuando no hay proceso en CPU

for arg in "$@"
do
	if [[ "$arg" == "-d" ]]
	then
		debug=1
		gl_debug=1
	elif [[ "$arg" == "-d2" ]]
	then
		debug2=1
		gl_debug=1
	elif [[ "$arg" == "-d3" ]]
	then
		debug3=1
		gl_debug=1
	elif [[ "$arg" == "-auto" ]]
	then
		auto=1
	elif [[ "$arg" == "-ba" ]]
	then
		gl_ajuste="ba"
	elif [[ "$arg" == "-fa" ]]
	then
		gl_ajuste="fa"
	elif [[ "$arg" == "-wa" ]]
	then
		gl_ajuste="wa"
	elif [[ "$arg" == "-ns" ]]
	then
		gl_no_saltos=1
	elif [[ "$arg" == "-c" ]]
	then
		gl_color=1
	fi
done

#vector de colores modificado para que todos puedan ser vistos sin problema.
color_default="\e[37;m"
bg_color_green="\e[42m"
bg_color_red="\e[41m"
for (( i=0; i < 25; i++ ));do
	c=`expr ${i} + 1`
	if [ $i -eq 14 ];then
		COLORS[14]="\e[38;5;124m"
		BG_COLORS[14]="\e[124m"
	elif [ $i -eq 15 ];then
		COLORS[15]="\e[38;5;154m"
		BG_COLORS[15]="\e[154m"
	elif [[ $i -eq 6 ]]; then
		COLORS[$i]="\e[38;5;99m"
		BG_COLORS[$i]="\e[48;5;99m"
	elif [[ $i -eq 11 ]]; then
		COLORS[$i]="\e[38;5;33m"
		BG_COLORS[$i]="\e[48;5;33m"
	elif [[ $i -eq 7 ]]; then
		COLORS[$i]="\e[38;5;202m"
		BG_COLORS[$i]="\e[48;5;202m"
	elif [[ $i -eq 3  ]]; then
		COLORS[$i]="\e[38;5;49m"
		BG_COLORS[$i]="\e[48;5;49m"
	else			
		COLORS[$i]="\e[38;5;${c}m"
		BG_COLORS[$i]="\e[48;5;${c}m"
	fi
	#echo -e "COLORS[$i] = ${COLORS[$i]}COLOR CHULI${color_default}, FONDO CHULI ${color_default}${BG_COLORS[$i]} FONDACO {$color_default}"
done

#echo "COLORS uno mas = ${COLORS[33]}"
#read -p "gohagoiag"


#read -p "Debug mode: $debug, alignment $gl_ajuste"
# Nos permite saber si el parámetro pasado es entero positivo.
es_entero() {
    [ "$1" -eq "$1" -a "$1" -ge "0" ] > /dev/null 2>&1  # En caso de error, sentencia falsa (Compara variables como enteros)
    return $?                           				# Retorna si la sentencia anterior fue verdadera
}

# Nos permite saber si el parámetro pasado es entero mayor que 0.
mayor_cero() {
    [ "$1" -eq "$1" -a "$1" -gt "0" ] > /dev/null 2>&1  # En caso de error, sentencia falsa (Compara variables como enteros)
    return $?                           				# Retorna si la sentencia anterior fue verdadera
}

# Comprobación para saber si el momento de E/S introducido es válido.
comprueba_momentos() {
	
	if mayor_cero $momento
		then
		if [ "$momento" -gt "$momentofinal" ]
			then
			return 1 	# Si el momento introducido es mayor la finalización del proceso (1 - falso)
		else
			return 0	# Si el momento introducido es entero y menor que la finalización del proceso (0 - verdadero)
		fi
	else
		return 1 		# Si el momento introducido no es entero (1 - falso)
	fi
}


# Función que calcula el número de espacios en base a las cifras para una tabla equilibrada
calcula_espacios(){

	cifras=`expr 1000`
	dato=$1
	if [ $1 -eq '0' ]
		then
		dato=`expr $dato + 1`
	fi
	while [ $dato -lt $cifras ]
	do
		fila=${fila}" "	
		cifras=$((cifras / 10))
	done
}

#Lee los datos linea por linea del fichero
lectura_datos(){

	indice=0
	for line in $(cat ./$fich);
	do
		datos[$indice]=$line
		indice=`expr $indice + 1` 
	done
}

#almacena cada línea del fichero en lugar de cada valor.
lectura_lineas(){

	indice=0
	IFS=$'\n'
	for l in $(cat ./$fich);
	do
		lines[$indice]=$l
		indice=`expr $indice + 1` 
	done
}

# Lee los datos desde un fichero
lectura_fichero() {
	procesos_ejecutables=`expr 0`
	act=`expr 0` # identificador de la linea actual para diferenciar el array al que pertenece el dato
	num_proc=`expr 0`
	local continuar
	local cabe
	local primera_vez
	local part_i
	echo "Fich= ${fich}"
	cp $fich copia.rr
	fich="copia.rr"

	if [ $opcion = "a" ] #RR
	then
		lectura_datos # almacena en el array $datos cada una de las lineas del fichero, 0..Num lineas -1
		lectura_lineas
		#se ejecuta por defecto el mejor ajuste
		gl_ajuste="ba"
		count=0
		#recoge el valor de la línea de particiones y lo almacena en la variable global
		IFS=" "
		for valor in ${lines[0]};do
			PART_SIZE[$count]=${valor}
			((count++))
		done
			n_par=$count
			#parte del sistema antiguo para leer los procesos
			position=`expr $step + 2`
			quantum=`expr ${lines[1]}`
			position=`expr $step + 2`d
			sed -i "1,"$position"" $fich

			# Recorrido del fichero linea a linea
			while IFS=" " read entrada rafaga memoria;do
				 if [  "$entrada" == "" ];then #si la linea esta vacía no hay mas procesos
					# echo "no hay mas procesos"
					 break
				fi
				T_ENTRADA_I[$num_proc]=`expr $entrada`
				if [ "${T_ENTRADA_I[$num_proc]}" == 0 ]
				then
					EN_ESPERA_I[$num_proc]="No"
					procesos_ejecutables=`expr $procesos_ejecutables + 1`
				else
					EN_ESPERA_I[$num_proc]="Si"
				fi
				continuar=0
			    while [ $continuar -eq 0 ]
			    do
			    	cabe=0
			    	primera_vez=1 # Nos servira para controlar que el indice 0 de particiones de memoria no se usa
					for (( part_i=0; part_i < $n_par; part_i++ ));do # Para cada particion de memoria de la lista PART_SIZE...
						mem_part=${PART_SIZE[$part_i]}
	
						if [ $debug -eq 1 ];then
							echo "Comparanado memoria de PART_SIZE[$part_i]=${mem_part} vs proceso memoria ${memoria}"
						fi
						if [ $memoria -le $mem_part ];then # Cabe en una particion
							if [ $debug -eq 1 ];then
								echo "Detectada particoin que cabe!"
							fi
							cabe=1
							continuar=1
							break
						fi
					done
					if [ $cabe -eq 0 ]; then
						echo "ERROR!!!! No cabe en ninguna particion de memoria el proceso ${num_proc}!"
						exit 1
					fi
				done
				MEMORIA_I[$num_proc]=`expr $memoria`
				PROCESOS_I[$num_proc]=`expr $rafaga`
				QT_PROC_I[$num_proc]=$quantum 	# Almacenará el quantum restante del proceso (en caso de E/S)
				PROC_ENAUX_I[$num_proc]="No" 	# Por defecto ningún proceso estará en la cola auxiliar FIFO de E/S
				num_proc=`expr $num_proc + 1`
			
			done < $fich

	

	else #RRV
		lectura_datos # almacena en el array $datos cada una de las lineas del fichero, 0..Num lineas -1
		gl_ajuste=$datos[0]
		#if [ "${gl_ajuste}" != "fa" -a "${gl_ajuste}" != "ba" -a "${gl_ajuste}" != "wa" ];then
		#	read -p "ERROR lectura de fichero erronea, ajuste no localizado"
		#else
		n_par=`expr ${datos[1]}`
		step=`expr 0`
		while [ $n_par -gt $step ];
		do
			position=`expr $step + 2`
			PART_SIZE[$step]=`expr ${datos[$position]}`
			((step++))
		done
		
		position=`expr $step + 2`
		quantum=`expr ${datos[$position]}`
		position=`expr $step + 3`d
		sed -i "1,"$position"" $fich
			
		while IFS=" " read entrada espera memoria rafaga entradaSalida momento duracion;do
			 if [  "$entrada" == "fin" ];then #si la linea esta vacía no hay mas procesos
				# echo "no hay mas procesos"
				 break
			fi
			#echo "$entrada, $espera, $memoria, $rafaga"
			if [ $debug -eq 1 ];then
				echo "Lectura de fichero leyendo RRV entrada=$entrada"
			fi
			T_ENTRADA_I[$num_proc]=`expr $entrada`
			EN_ESPERA_I[$num_proc]=$espera
			if [ "${EN_ESPERA_I[$num_proc]}" == "No" ]
			then
				procesos_ejecutables=`expr $procesos_ejecutables + 1`
			fi
			MEMORIA_I[$num_proc]=`expr $memoria`
			PROCESOS_I[$num_proc]=`expr $rafaga`
			QT_PROC_I[$num_proc]=$quantum 	# Almacenará el quantum restante del proceso (en caso de E/S)
			PROC_ENAUX_I[$num_proc]="No" 	# Por defecto ningún proceso estará en la cola auxiliar FIFO de E/S
			if [ "$entradaSalida" == "Si" ];
			then
				if [ $debug -eq 1 ];then
					echo "Lectura de fichero leyendo RRV con un proceso de E/S para el proceso $num_proc"
				fi
			fi
			ENTRADA_SALIDA[$num_proc]=$entradaSalda
			MOMENTO[$num_proc]=$momento 	# Solo en caso E/S para el RRV
			DURACION[$num_proc]=$duracion 	# Solo en caso E/S para el RRV
			num_proc=`expr $num_proc + 1`
		
		done < $fich
		
	fi
	rm $fich

	datos_fichTfich
	ordenacion_procesos


	mostrar_menu_tipo_ejecucion_algoritmo


	imprimir_tabla
		
}

#leer fichero de configuraccion 

lectura_fichero_config(){
	clear
	imprime_cabecera

	local fich_cfg
	local explode_cfg
	local sub_explode_cfg
	declare -A arra_cfg
	fich_cfg="$1"

	echo "" > "ultimaRandomRR.temp"
	while IFS= read -r line
	do
		explode_cfg=(${line//=/ }) 
		local temp_sub_1
		temp_sub_1=${explode_cfg[0]}
		local temp_sub
		temp_sub=${explode_cfg[1]}
		sub_explode_cfg=(${temp_sub//-/ }) 

		arra_cfg[$temp_sub_1,0]=${sub_explode_cfg[0]}
		arra_cfg[$temp_sub_1,1]=${sub_explode_cfg[1]}

	done < $fich_cfg

	crear_fich_temp_memrias_random $arra_cfg
	crear_fich_temp_quantum_random $arra_cfg
	crear_fich_temp_procesos_random $arra_cfg
	
	fich="ultimaRandomRR.temp"

	#Antes de hacer esto hay que asiganar el tipo de lectura que es 
	# fa-fa
	gl_ajuste=${arra_cfg[ajuste,0]}
	lectura_fichero #

	rm "ultimaRandomRR.temp"

}

crear_fich_temp_procesos_random(){

	local numero_procesos
	numero_procesos=$(( $RANDOM % ( ${arra_cfg[num_procesos,1]} - ${arra_cfg[num_procesos,0]} ) + ${arra_cfg[num_procesos,0]} ))

	count=0
	while [ $count -le $numero_procesos ]
	do

		local tiempo_llegada_procesos 
		local rafaga_procesos 
		local memoria_procesos 
		tiempo_llegada_procesos=$(( $RANDOM % ( ${arra_cfg[tiempo_llegada_procesos,1]} - ${arra_cfg[tiempo_llegada_procesos,0]} ) + ${arra_cfg[tiempo_llegada_procesos,0]} ))
		rafaga_procesos=$(( $RANDOM % ( ${arra_cfg[rafaga_procesos,1]} - ${arra_cfg[rafaga_procesos,0]} ) + ${arra_cfg[rafaga_procesos,0]} ))
		memoria_procesos=$(( $RANDOM % ( ${arra_cfg[memoria_procesos,1]} - ${arra_cfg[memoria_procesos,0]} ) + ${arra_cfg[memoria_procesos,0]} ))

		while [ $tamanyoMaximoParticion -lt $memoria_procesos ]
		do
			memoria_procesos=$(( $RANDOM % ( ${arra_cfg[memoria_procesos,1]} - ${arra_cfg[memoria_procesos,0]} ) + ${arra_cfg[memoria_procesos,0]} ))
		done

		echo "$tiempo_llegada_procesos $rafaga_procesos $memoria_procesos" >> "ultimaRandomRR.temp"
		count=$(( $count + 1 ))
	done

}

crear_fich_temp_quantum_random(){
	local tamanyo_quantum
	local texto_archivo
	tamanyo_quantum=$(( $RANDOM % ( ${arra_cfg[tamanyo_quantum,1]} - ${arra_cfg[tamanyo_quantum,0]} ) + ${arra_cfg[tamanyo_quantum,0]} ))

	echo $tamanyo_quantum >> "ultimaRandomRR.temp"
}

crear_fich_temp_memrias_random(){

	local numero_particiones
	local texto_archivo
	numero_particiones=$(( $RANDOM % ( ${arra_cfg[num_particiones,1]} - ${arra_cfg[num_particiones,0]} ) + ${arra_cfg[num_particiones,0]} ))
	tamanyoMaximoParticion=0

	count=0
	while [ $count -le $numero_particiones ]
	do	
		local tamanyo_particion 
		tamanyo_particion=$(( $RANDOM % ( ${arra_cfg[tamanyo_particiones,1]} - ${arra_cfg[tamanyo_particiones,0]} ) + ${arra_cfg[tamanyo_particiones,0]} ))

		# Saco caul es el tamño maximo de la particion
		# Mas tarde lo usare en el crear los procesos 
		if [ $tamanyoMaximoParticion -le $tamanyo_particion ];then
			tamanyoMaximoParticion=$tamanyo_particion	
		fi

		
		texto_archivo="$texto_archivo $tamanyo_particion"
		count=$(( $count + 1 ))
	done

	echo $texto_archivo > "ultimaRandomRR.temp"

}

#pregunta si se desea introducir mas datos a la función
new_proc() {
	read -p " ¿desea introducir un proceso nuevo? ([s]/n) " proc_new
	echo " ¿desea introducir un proceso nuevo? ([s]/n) " >> informeRR.txt
	echo $proc_new >> informeRR.txt
	echo " ¿desea introducir un proceso nuevo? ([s]/n) " >> informeColor.txt
	echo $proc_new >> informeColor.txt
	if [ -z $proc_new ]
		then
		proc_new="s"
	fi

	while [ "${proc_new}" != "s" -a "${proc_new}" != "n" ]
	do
		read -p " Entrada no válida, vuelve a intentarlo. ¿desea intoducir un proceso nuevo? ([s]/n) " proc_new
		if [ -z $proc_new ]
			then
			proc_new="s"
		fi
	done	 
}

#imprime los datos metidos hasta el momento
imprimir_tabla() {
	if [ $opcion = "a" ]
		then
		clear
		
		#imprime_cabecera
		echo -e "\n RR-FNI-MEJOR "
		echo -e "\n RR-FNI-MEJOR " >> informeRR.txt
		echo -e "\n RR-FNI-MEJOR " >> informeColor.txt
		echo -ne " QUANTUM = $quantum "
		echo -ne " QUANTUM = $quantum " >> informeRR.txt
		echo -ne " QUANTUM = $quantum " >> informeColor.txt
		for ipar in ${!PART_SIZE[*]};do
			TAM_PART[$ipar]=${PART_SIZE[$ipar]}
			echo -n  "  PART $ipar = ${PART_SIZE[$ipar]}"
			echo -n  "  PART $ipar = ${PART_SIZE[$ipar]}" >> informeRR.txt
			echo -n  "  PART $ipar = ${PART_SIZE[$ipar]}" >> informeColor.txt
		done
		echo -e "\n Ref Tll Tej Mem"
		echo -e "\n Ref Tll Tej Mem" >> informeRR.txt
		echo -e "\n Ref Tll Tej Mem" >> informeColor.txt
		for((xp=0 ; xp < $num_proc ; xp++ ))
		do
			PROC_COLORS[${PROC[$xp]}]=${COLORS[PROC[$xp]]}

			#echo -e "Proceso num ${PROC[$xp]} tiene asociado ${PROC_COLORS[${PROC[${xp}]}]}este color${color_default}"
			#echo -e "\t\t\t\e[0;32m${PROC[$xp]}\e[0m\t \t\e[1;29m${T_ENTRADA[$xp]}\e[0m\t \t\e[1;38m${PROCESOS[$xp]}\e[0m\t \t\e[1;39m${MEMORIA[$xp]}\e[0m"
			if [ ${PROC[$xp]} -lt 10 ];then
				printf " ${COLORS[PROC[$xp]]}P0%s  %2s  %2s  %2s$color_default\n" ${PROC[$xp]} ${T_ENTRADA[$xp]}   ${PROCESOS[$xp]}  ${MEMORIA[$xp]}
				printf " P0%s  %2s  %2s  %2s\n" ${PROC[$xp]} ${T_ENTRADA[$xp]}   ${PROCESOS[$xp]}  ${MEMORIA[$xp]} >> informeRR.txt
				printf " ${COLORS[PROC[$xp]]}P0%s  %2s  %2s  %2s$color_default\n" ${PROC[$xp]} ${T_ENTRADA[$xp]}   ${PROCESOS[$xp]}  ${MEMORIA[$xp]} >> informeColor.txt		
				#echo -e " ${COLORS[PROC[$xp]]}P0${PROC[$xp]}   ${T_ENTRADA[$xp]}   ${PROCESOS[$xp]}  ${MEMORIA[$xp]}${color_default}"
			else
				printf " ${COLORS[PROC[$xp]]}P%s  %2s  %2s  %2s$color_default\n" ${PROC[$xp]} ${T_ENTRADA[$xp]}   ${PROCESOS[$xp]}  ${MEMORIA[$xp]}
				printf " P%s  %2s  %2s  %2s\n" ${PROC[$xp]} ${T_ENTRADA[$xp]}   ${PROCESOS[$xp]}  ${MEMORIA[$xp]} >> informeRR.txt
				printf " ${COLORS[PROC[$xp]]}P%s  %2s  %2s  %2s$color_default\n" ${PROC[$xp]} ${T_ENTRADA[$xp]}   ${PROCESOS[$xp]}  ${MEMORIA[$xp]} >> informeColor.txt
				#echo -e " ${COLORS[PROC[$xp]]}P${PROC[$xp]}   ${T_ENTRADA[$xp]}   ${PROCESOS[$xp]}  ${MEMORIA[$xp]}${color_default}"
			fi
		done
	else
		clear
		imprime_cabecera
		echo "Procesos introducidos: "
		echo "		  PRO   LLEGADA   RAFAGA   MEMORIA   E/S   TP_E/S " 
		for(( xp=0 ; xp < $num_proc ; xp++ ))
		do
			echo "		    "$[$xp+1]" 		${T_ENTRADA[$xp]} 	${PROCESOS[$xp]} 	${MEMORIA[$xp]} 	${MOMENTO[$p]} 	${DURACION[$p]}"
	
		done	
		echo "		QUANTUM: $quantum"
		
	fi
	echo -e "\n\n"

	if [ "$proc_new" == "n" ] || [ "$dat_fich" == "s" ];then
		read -p " Pulsa <ENTER> para continuar"
	fi
}

rellenarHuecos(){
	local _texto="$1"
	local _index="$1"
	local _top="$2"
	for(( i=${#_index} ; i<= $_top ; i++))
	do

		if [ "$3" == "n" ];then
			_texto="$_texto "
		else
			_texto=" $_texto"
		fi

	done
	
	echo "$_texto"
}

# Lee los datos concretos de los procesos por pantalla.
lectura_datprocesos() {
	local primera_vez
	local memo_proc
	local mem_part
	local cabe
	local part
	local continuar
	procesos_ejecutables=`expr 0`

	# COMENZAMOS A LEER RAFAGAS DE LOS PROCESOS
	cntproc=`expr 0`
	while [ $proc_new = "s" ]
	do
		proc=`expr $cntproc + 1`    # PROCESO ACTUAL
	    
	 	#IMPRIME TABLAS CON DATOS
        if [ $num_proc -ne 0 ]
        then
            ordenacion_procesos
            imprimir_tabla
        fi
		(( num_proc++ ))

	    # LECTURA DE LLEGADA 
	    if [[ $proc -lt 10 ]]; then
	    	echo -ne " Introduce el momento de llegada a CPU del proceso ${COLORS[$proc]}P0$proc$color_default:"
	    	echo -n " Introduce el momento de llegada a CPU del proceso P0$proc:" >> informeRR.txt
	    	echo -ne " Introduce el momento de llegada a CPU del proceso ${COLORS[$proc]}P0$proc$color_default:" >> informeColor.txt
	    	read entrada
	    	echo $entrada  >> informeRR.txt
	    	echo $entrada  >> informeColor.txt
	    else
	    	echo -ne " Introduce el momento de llegada a CPU del proceso ${COLORS[$proc]}P$proc$color_default:"
	    	echo -n " Introduce el momento de llegada a CPU del proceso P$proc:" >> informeRR.txt
	    	echo -ne " Introduce el momento de llegada a CPU del proceso ${COLORS[$proc]}P$proc$color_default:" >> informeColor.txt
	    	read entrada
	    	echo $entrada  >> informeRR.txt
	    	echo $entrada  >> informeColor.txt
	    fi
	    
	    
	    if [ -z $entrada ] # Si la entrada está vacía, valor por defecto 0
	    	then
	    	entrada=`expr 0`
	    else
	        # COMPROBACIÓN DE LECTURA
	        while ! es_entero $entrada
	        do
	        	clear
	        	echo "Entrada no válida"
	        	if [[ $proc -lt 10 ]]; then
			    	echo -ne " Introduce el momento de llegada a CPU del proceso ${COLORS[$proc]}P0$proc$color_default:"
			    	echo -n " Introduce el momento de llegada a CPU del proceso ${COLORS[$proc]}P0$proc:" >> informeRR.txt
			    	echo -ne " Introduce el momento de llegada a CPU del proceso ${COLORS[$proc]}P0$proc$color_default:" >> informeColor.txt
			    	read entrada
			    	echo $entrada  >> informeRR.txt
	    			echo $entrada  >> informeColor.txt
			    else
			    	echo -ne " Introduce el momento de llegada a CPU del proceso ${COLORS[$proc]}P$proc$color_default:"
			    	echo -n " Introduce el momento de llegada a CPU del proceso ${COLORS[$proc]}P0$proc:" >> informeRR.txt
			    	echo -ne " Introduce el momento de llegada a CPU del proceso ${COLORS[$proc]}P0$proc$color_default:" >> informeColor.txt
			    	read entrada
			    	echo $entrada  >> informeRR.txt
	    			echo $entrada  >> informeColor.txt
			    fi
	        	if [ -z $entrada ] # Si la entrada está vacía, valor por defecto 0
	        		then
	        		entrada=`expr 0`
	        	fi
	        done
	    fi
	    #Almacenamiento de valores en sus arrays
	    if [ $entrada -ne '0' ]
	    	then
	    	T_ENTRADA_I[$cntproc]="$entrada"
	    	EN_ESPERA_I[$cntproc]="Si"
	    else
	    	T_ENTRADA_I[$cntproc]="$entrada"
	    	EN_ESPERA_I[$cntproc]="No"
	    	procesos_ejecutables=`expr $procesos_ejecutables + 1`
	    fi
	    T_ENTRADA[$xp]=$entrada
	    PROC[$xp]=$num_proc
	    
	    
	    #Almacenamiento de datos en un archivo temporal
	    #echo ${T_ENTRADA_I[$cntproc]} >> archivo.temp
	    #echo ${EN_ESPERA_I[$cntproc]} >> archivo.temp

	    # LECTURA DE RAFAGA
	    if [[ $proc -lt 10 ]]; then
	    	 echo -ne " Introduce la ráfaga de CPU del proceso ${COLORS[$proc]}P0$proc$color_default:"
	    	 echo -n " Introduce la ráfaga de CPU del proceso P0$proc:" >> informeRR.txt
	    	 echo -ne " Introduce la ráfaga de CPU del proceso ${COLORS[$proc]}P0$proc$color_default:" >> informeColor.txt
			 read rafaga
			 echo $rafaga >> informeRR.txt
			 echo $rafaga >> informeColor.txt
	    else
	    	 echo -ne " Introduce la ráfaga de CPU del proceso ${COLORS[$proc]}P$proc$color_default:"
	    	 echo -n " Introduce la ráfaga de CPU del proceso P$proc:" >> informeRR.txt
	    	 echo -ne " Introduce la ráfaga de CPU del proceso ${COLORS[$proc]}P$proc$color_default:" >> informeColor.txt
			 read rafaga
			 echo $rafaga >> informeRR.txt
			 echo $rafaga >> informeColor.txt
	    fi
	   
		# LECTURA DEL TAMAÑO DE MEMORIA
	#read -p "Introduce el tamaño de memoria del proceso $proc:" tamano[$proc]
	    # COMPROBACIÓN DE LECTURA
	    while ! mayor_cero $rafaga
	    do
	    	clear
	    	echo "Entrada no válida"
	    	if [[ $proc -lt 10 ]]; then
		    	 echo -ne " Introduce la ráfaga de CPU del proceso ${COLORS[$proc]}P0$proc$color_default:"
				 echo -n " Introduce la ráfaga de CPU del proceso P0$proc:" >> informeRR.txt
		    	 echo -ne " Introduce la ráfaga de CPU del proceso ${COLORS[$proc]}P0$proc$color_default:" >> informeColor.txt
				 read rafaga
				 echo $rafaga >> informeRR.txt
				 echo $rafaga >> informeColor.txt
		    else
		    	 echo -ne " Introduce la ráfaga de CPU del proceso ${COLORS[$proc]}P$proc$color_default:"
				 echo -n " Introduce la ráfaga de CPU del proceso P$proc:" >> informeRR.txt
		    	 echo -ne " Introduce la ráfaga de CPU del proceso ${COLORS[$proc]}P$proc$color_default:" >> informeColor.txt
				 read rafaga
				 echo $rafaga >> informeRR.txt
				 echo $rafaga >> informeColor.txt
		    fi
	    done
	    PROCESOS[$xp]=$rafaga
	    #Almacenamiento de datos en un archivo temporal
	    #echo $rafaga >> archivo.temp
	    # GUARDAMOS LA RAFAGA EN EL PROCESO
	    PROCESOS_I[$cntproc]=$rafaga  # Almacenará la ráfaga del proceso
	    QT_PROC_I[$cntproc]=$quantum 	# Almacenará el quantum restante del proceso (en caso de E/S)
		PROC_ENAUX_I[$cntproc]="No" 	# Por defecto ningún proceso estará en la cola auxiliar FIFO de E/S
		#LECTURA DE LA MEMORIA QUE OCUPA EL PROCESO
		if [[ $proc -lt 10 ]]; then
			echo -ne " Introduce la memoria_disponible del proceso ${COLORS[$proc]}P0$proc$color_default:"
			echo -n " Introduce la memoria_disponible del proceso P$proc:" >> informeRR.txt
			echo -ne " Introduce la memoria_disponible del proceso ${COLORS[$proc]}P0$proc$color_default:" >> informeColor.txt
			read memo_proc
			echo $memo_proc >> informeRR.txt
			echo $memo_proc >> informeColor.txt

		else
			echo -ne " Introduce la memoria_disponible del proceso ${COLORS[$proc]}P$proc$color_default:"
			echo -n " Introduce la memoria_disponible del proceso P$proc:" >> informeRR.txt
			echo -ne " Introduce la memoria_disponible del proceso ${COLORS[$proc]}P0$proc$color_default:" >> informeColor.txt
			read memo_proc
			echo $memo_proc >> informeRR.txt
			echo $memo_proc >> informeColor.txt
		fi
		
		while ! mayor_cero $memo_proc
	    do
	    	clear
	    	echo "Entrada no válida"
	    	if [[ $proc -lt 10 ]]; then
			echo -ne " Introduce la memoria_disponible del proceso ${COLORS[$proc]}P0$proc$color_default:"
			echo -n " Introduce la memoria_disponible del proceso P$proc:" >> informeRR.txt
			echo -ne " Introduce la memoria_disponible del proceso ${COLORS[$proc]}P0$proc$color_default:" >> informeColor.txt
			read memo_proc
			echo $memo_proc >> informeRR.txt
			echo $memo_proc >> informeColor.txt

		else
			echo -ne " Introduce la memoria_disponible del proceso ${COLORS[$proc]}P$proc$color_default:"
			echo -n " Introduce la memoria_disponible del proceso P$proc:" >> informeRR.txt
			echo -ne " Introduce la memoria_disponible del proceso ${COLORS[$proc]}P0$proc$color_default:" >> informeColor.txt
			read memo_proc
			echo $memo_proc >> informeRR.txt
			echo $memo_proc >> informeColor.txt
		fi
	    done

	    continuar=0
	    while [ $continuar -eq 0 ]
	    do
	    	cabe=0
	    	primera_vez=1 # Nos servira para controlar que el indice 0 de particones de ememoria no se usa
			for (( part=0; part < $n_par; part++ ));do # Para cada particion de memoria de la lista PART_SIZE...
				mem_part=${PART_SIZE[$part]}

				if [ $debug -eq 1 ];then
					echo "Comparanado memoria de PART_SIZE[$part]=${mem_part} vs proceso memoria ${memo_proc}"
				fi
				if [ $memo_proc -le $mem_part ];then # Cabe en una particion
					if [ $debug -eq 1 ];then
						echo "Detectada particoin que cabe!"
					fi
					cabe=1
					continuar=1
					break
				fi
			done
			if [ $cabe -eq 0 ]; then
				echo " ERROR!!!! No cabe en ninguna particion de memoria este proceso"
				read -p " Introduce la memoria del proceso $proc:" memo_proc
			fi
		done
		MEMORIA[$xp]=$memo_proc
	    # GUARDAMOS LA MEMORIA EN EL PROCESO
	    MEMORIA_I[$cntproc]=$memo_proc  # Almacenará la memoria del proceso	

		if [ $opcion = "b" ]
			then

			read -p " ¿Es un proceso de E/S? (s/n): " tipo

			# COMPROBACIÓN DE LECTURA
			if [ -z $tipo ]
				then
				tipo="n"
				momento="N/A"
			fi
			
			while [ $tipo != "s" -a $tipo != "n" ]
			do
				clear
				echo " Entrada no válida"
				read -p " ¿Es un proceso de E/S? (s/n): " tipo
				if [ -z $tipo ]
					then
					tipo="n"
					momento="N/A"
				fi
			done			
			
			if [ $tipo = "s" ]
				then
				momentofinal=`expr $rafaga - 1`
				read -p " En que momento se produce la situación de E/S? (1 - $momentofinal): " momento
				# COMPROBACIÓN DE LA LECTURA
				while ! comprueba_momentos
				do
					clear
					echo " Entrada no válida"
					read -p " ¿En que momento se produce la situación de E/S? (1 - $momentofinal): " momento
				done
				MOMENTO[$cntproc]="$momento"

				read -p " ¿Cual es la duración de la situación de espera? " duracion
				# COMPROBACIÓN DE LA LECTURA
				while ! mayor_cero $duracion
				do
					clear
					echo " Entrada no válida"
					read -p " ¿Cual es la duración de la situación de espera? " duracion
				done
				DURACION[$cntproc]="$duracion"
			else
				tipo="n"
				momento="N/A"
			fi

			#Almacenamiento de datos en un archivo temporal
			#echo ${MOMENTO[$cntproc]} >> archivo.temp
			#echo ${DURACION[$cntproc]} >> archivo.temp

		fi
		if [ $entrada -lt $min ]
			then
				min=$entrada
				pos=$cntproc
		fi
		#echo "el numero de proceso es $cntproc"
		let cntproc=`expr $cntproc + 1`
		#echo "ahora vale $cntproc despues de ser incrementado"
		#sleep 3
		new_proc
		
	done

	if [ $procesos_ejecutables -eq 0 ]
		then
			EN_ESPERA[$pos]="No"
		   	procesos_ejecutables=`expr $procesos_ejecutables + 1`
	fi
	imprimir_tabla
}

#Ordena los procesos por tiempo de llegada
ordenacion_procesos() {
	local index
	proceso=`expr 0`
	for (( nn=1; $proceso < $num_proc  ; nn++ ))
	do
		for (( j=0; j < $num_proc ; j++ ))
		do
				index=`expr $nn - 1`
			
				if [ ${T_ENTRADA_I[$j]} -eq $index ] 
				then
					PROCESOS[$proceso]=`expr ${PROCESOS_I[$j]}`
					MEMORIA[$proceso]=`expr ${MEMORIA_I[$j]}`
					T_ENTRADA[$proceso]=`expr ${T_ENTRADA_I[$j]}`
					EN_ESPERA[$proceso]=`expr ${EN_ESPERA_I[$j]}`
					QT_PROC[$proceso]=`expr ${QT_PROC_I[$j]}`
					PROC_ENAUX[$proceso]=`expr ${PROC_ENAUX_I[$j]}`
					PROC[$proceso]=`expr $j + 1`
					FIN[$proceso]=`expr 0`
					TIEMPO[$proceso]=`expr ${PROCESOS_I[$j]}`
					proceso=`expr $proceso + 1`
				fi
			#fi
		done
	done
}

#guarda datos en en auxiliares para evitar su modificacion
datos_aux(){
	for(( cc=0 ; cc < $num_proc ; cc++ ))
	do
		RAFAGA_AUX[$cc]=`expr ${PROCESOS[$cc]}`
		MEMORIA_AUX[$cc]=`expr ${MEMORIA[$cc]}`
		
	done
}

#comprueba si un proceso entra en memoria guardandolo en un array
en_memoria(){
	for(( co=0 ; co < $num_proc ; co++ ))
	do
	
	if [ ${MEMORIA[$co]} -ne ${MEMORIA_AUX[$co]} ]
	then
		EN_MEMO[$co]="No"
	fi
	done

}

#mete la tabla final en el informe que se da la opcion de visualizar al final del programa
datosfin_inf() {

	en_memoria
	local en_memoria
	local t_espera
	media=`expr 0`

	suma_contexto=0

	echo -e "\n\t\tRESUMEN\n"  >> informeRR.txt
	echo " "  >> informeRR.txt
	echo -e "	  PRO   T LLEGADA   RAFAGA   MEMORIA   EN MEMORIA   L TEMP   ESTADO"   >> informeRR.txt
	echo -e "\n\t\tRESUMEN\n"  >> informeColor.txt
	echo " "  >> informeColor.txt
	echo -e "	  PRO   T LLEGADA   RAFAGA   MEMORIA   EN MEMORIA   L TEMP   ESTADO"   >> informeColor.txt
		for(( xp=0 ; xp < $num_proc ; xp++ ))
		do
			if [[ ${PART[$xp]} -gt -1 ]];then
				en_memoria="Si"
			else
				en_memoria="No"
			fi
			echo "	    ${PROC[$xp]}		${T_ENTRADA[$xp]}	${RAFAGA_AUX[$xp]}	${MEMORIA_AUX[$xp]}        ${en_memo}	     ${TIEMPO_FIN[$xp]}      ${ESTADO[$xp]}"  >> informeRR.txt
			echo -e "	    ${PROC_COLORS[${PROC[$xp]}]}${PROC[$xp]}		${T_ENTRADA[$xp]}	${RAFAGA_AUX[$xp]}	${MEMORIA_AUX[$xp]}        ${en_memo}	     ${TIEMPO_FIN[$xp]}      ${ESTADO[$xp]}${color_default}"  >> informeColor.txt

		done
		
		echo -e "\n\t\tTIEMPOS DE ESPERA Y RETORNO\n" >> informeRR.txt	
		echo " 	    PRO    T RETORNO    T ESPERA   "  >> informeRR.txt
		echo -e "\n\t\tTIEMPOS DE ESPERA Y RETORNO\n" >> informeColor.txt	
		echo " 	    PRO    T RETORNO    T ESPERA   "  >> informeColor.txt


	
		for(( xp=0 ; xp < $num_proc ; xp++ ))
		do
		
			if [ "${ESTADO[$xp]}" != "Bloqueado" ]
			then

				T_RETORNO[$xp]=`expr ${TIEMPO_FIN[$xp]} - ${T_ENTRADA[$xp]}`
				T_ESPERA[$xp]=`expr ${TIEMPO_FIN[$xp]} - ${T_ENTRADA[$xp]} - ${RAFAGA_AUX[$xp]}`
				suma_contexto=`expr $suma_contexto + ${CONTEXTO[$xp]}`

			else

				T_RETORNO[$xp]=0
				T_ESPERA[$xp]=0		

			fi
			t_espera=${T_ESPERA[$xp]}
			if [[ $t_espera -lt 0 ]];then
				t_espera="N/A"
				T_ESPERA[$xp]=0
			fi
			T_MEDIO_R=`expr $T_MEDIO_R + ${T_RETORNO[$xp]}`
			T_MEDIO_E=`expr $T_MEDIO_E + ${T_ESPERA[$xp]}`

			echo "	       ${PROC[$xp]}   	    ${T_RETORNO[$xp]}      ${t_espera}"  >> informeRR.txt
			echo "	       ${PROC[$xp]}   	    ${T_RETORNO[$xp]}      ${t_espera}"  >> informeColor.txt
		
		done
	
	echo -ne "\t\tEl tiempo medio de retorno es: "  >> informeRR.txt
	echo " 		 scale = 2; $T_MEDIO_R/$num_proc"| bc  >> informeRR.txt	
	echo -ne "\t\tEl tiempo medio de espera es:  "  >> informeRR.txt
	echo "		 scale = 2; $T_MEDIO_E/$num_proc"| bc  >> informeRR.txt
	echo -ne "\t\tEl tiempo medio de retorno es: "  >> informeColor.txt
	echo " 		 scale = 2; $T_MEDIO_R/$num_proc"| bc  >> informeColor.txt	
	echo -ne "\t\tEl tiempo medio de espera es:  "  >> informeColor.txt
	echo "		 scale = 2; $T_MEDIO_E/$num_proc"| bc  >> informeColor.txt

	
		echo -e "\n\t\tCAMBIOS DE CONTEXTO\n" >> informeRR.txt
		echo -e "\t\t   PRO\t  n CAMBIOS CONTEXTO  "  >> informeRR.txt
		echo -e "\n\t\tCAMBIOS DE CONTEXTO\n" >> informeColor.txt
		echo -e "\t\t   PRO\t  n CAMBIOS CONTEXTO  "  >> informeColor.txt
		for(( xp=0 ; xp < $num_proc ; xp++ ))
		do
			echo -e "\t\t   ${PROC[$xp]}\t|\t${CONTEXTO[$xp]}   " >> informeRR.txt
			echo -e "\t\t   ${PROC[$xp]}\t|\t${CONTEXTO[$xp]}   " >> informeColor.txt
		done
		echo -e "\t\tNÚMERO TOTAL DE CAMBIOS DE CONTEXTO ES : $cambio_contexto\n"  >> informeRR.txt
		echo -e "\t\tNÚMERO TOTAL DE CAMBIOS DE CONTEXTO ES : $cambio_contexto\n"  >> informeColor.txt

}
#imprime una tabla final con los datos de los diferentes procesos
solucion_impresa() {
	local en_memoria
	local t_espera
	echo " Procesos terminados pulse ENTER para ver el resumen e informes"
	read -p ""
	clear
	en_memoria
	media=`expr 0`
	imprime_cabecera

	echo -e "\t\tESTADO FINAL DE LOS PROCESOS\n" 
	echo -e "\t\tESTADO FINAL DE LOS PROCESOS\n" >> informeColor.txt
	echo -e "\t\tESTADO FINAL DE LOS PROCESOS\n" >> informeRR.txt
	#echo -e "\t\t   PRO\t  T LLEGADA\t   RAFAGA\t   MEMORIA\t  EN MEMORIA\t     L TEMP\t   ESTADO\t"
	echo -e "\n\t Ref Tll Tej Mem Tesp Tret Trej Part ESTADO" 
	echo -e "\n\t Ref Tll Tej Mem Tesp Tret Trej Part ESTADO" >> informeColor.txt
	echo -e "\n\t Ref Tll Tej Mem Tesp Tret Trej Part ESTADO" >> informeRR.txt
		for(( xp=0 ; xp < $num_proc ; xp++ ))
		do
			if [  ${PROC[$xp]} -lt 10 ];then
				proc_column="P0${PROC[$xp]}"
			else
				proc_column="P${PROC[$xp]}"
			fi	
			if [ ${PART[$xp]} -eq -1 ] # esta particion esta libre
				then
				part=" - "
			else
				let part=PART[xp]
			fi
			printf "\t %3s  %2s  %2s  %2s " $proc_column ${T_ENTRADA[$xp]} ${RAFAGA_AUX[$xp]} ${MEMORIA[$xp]}
			printf "%4s   %2s  %3s  %3s" ${T_ESPERA[$xp]} ${T_RETORNO[$xp]} ${TIEMPO[$xp]} $parteOcupada
			printf " ${ESTADO[$xp]}${color_defaul}\n"
			printf "\t %3s  %2s  %2s  %2s " $proc_column ${T_ENTRADA[$xp]} ${RAFAGA_AUX[$xp]} ${MEMORIA[$xp]} >> informeColor.txt
			printf "%4s   %2s  %3s  %3s" ${T_ESPERA[$xp]} ${T_RETORNO[$xp]} ${TIEMPO[$xp]} $parteOcupada >> informeColor.txt
			printf " ${ESTADO[$xp]}${color_defaul}\n" >> informeColor.txt
			printf "\t %3s  %2s  %2s  %2s " $proc_column ${T_ENTRADA[$xp]} ${RAFAGA_AUX[$xp]} ${MEMORIA[$xp]} >> informeRR.txt
			printf "%4s   %2s  %3s  %3s" ${T_ESPERA[$xp]} ${T_RETORNO[$xp]} ${TIEMPO[$xp]} $parteOcupada >> informeRR.txt
			printf " ${ESTADO[$xp]}\n" >> informeRR.txt
			#echo -e "\t\t    ${PROC[$xp]}\t \t${T_ENTRADA[$xp]}\t \t${RAFAGA_AUX[$xp]}\t \t${MEMORIA_AUX[$xp]}\t \t${en_memoria}\t \t${TIEMPO_FIN[$xp]}\t   ${ESTADO[$xp]}" 	
		done
	echo -e "\n\t\tTIEMPOS DE ESPERA Y RETORNO\n"
	echo -e "\t\t   PRO\t   T ESPERA\t   T RETORNO\t"
	echo -e "\n\t\tTIEMPOS DE ESPERA Y RETORNO\n" >> informeColor.txt
	echo -e "\t\t   PRO\t   T ESPERA\t   T RETORNO\t" >> informeColor.txt
	echo -e "\n\t\tTIEMPOS DE ESPERA Y RETORNO\n" >> informeRR.txt
	echo -e "\t\t   PRO\t   T ESPERA\t   T RETORNO\t" >> informeRR.txt

		T_MEDIO_R=0
		T_MEDIO_E=0
		for(( xp=0 ; xp < $num_proc ; xp++ ))
		do	
			if [ "${ESTADO[$xp]}" == "Bloqueado" ]
			then
				T_RETORNO[$xp]=0
				T_ESPERA[$xp]=0			
			fi
			t_espera=${T_ESPERA[$xp]}

			if [[ ${T_ESPERA[$xp]} -lt 0 ]];then
				t_espera="N/A"
				T_ESPERA[$xp]=0
			fi
			if [[ ${T_RETORNO[$xp]} -lt 0 ]];then
				T_RETORNO[$xp]=0
			fi
			T_MEDIO_R=`expr $T_MEDIO_R + ${T_RETORNO[$xp]}`
			T_MEDIO_E=`expr $T_MEDIO_E + ${T_ESPERA[$xp]}`

			if [[ ${PROC[$xp]} -lt 10 ]]; then
				echo -e "\t\t   P0${PROC[$xp]}\t \t${t_espera}\t \t${T_RETORNO[$xp]}\t"
				echo -e "\t\t   P0${PROC[$xp]}\t \t${t_espera}\t \t${T_RETORNO[$xp]}\t" >> informeColor.txt
				echo -e "\t\t   P0${PROC[$xp]}\t \t${t_espera}\t \t${T_RETORNO[$xp]}\t" >> informeRR.txt
			else
				echo -e "\t\t   P${PROC[$xp]}\t \t${t_espera}\t \t${T_RETORNO[$xp]}\t"
				echo -e "\t\t   P0${PROC[$xp]}\t \t${t_espera}\t \t${T_RETORNO[$xp]}\t" >> informeColor.txt
				echo -e "\t\t   P0${PROC[$xp]}\t \t${t_espera}\t \t${T_RETORNO[$xp]}\t" >> informeRR.txt
			fi
		done
	echo -ne "\t\tEl tiempo medio de espera es:  "
	echo " scale = 2; $T_MEDIO_E/$num_proc"| bc	
	echo -ne "\t\tEl tiempo medio de retorno es: "
	echo "  scale = 2; $T_MEDIO_R/$num_proc"| bc	
	echo " "
	echo -ne "\t\tEl tiempo medio de espera es:  " >> informeColor.txt
	echo " scale = 2; $T_MEDIO_E/$num_proc"| bc	 >> informeColor.txt
	echo -ne "\t\tEl tiempo medio de retorno es: " >> informeColor.txt
	echo "  scale = 2; $T_MEDIO_R/$num_proc"| bc >> informeColor.txt
	echo -ne "\t\tEl tiempo medio de espera es:  " >> informeRR.txt
	echo " scale = 2; $T_MEDIO_E/$num_proc"| bc	 >> informeRR.txt
	echo -ne "\t\tEl tiempo medio de retorno es: " >> informeRR.txt
	echo "  scale = 2; $T_MEDIO_R/$num_proc"| bc >> informeRR.txt
		
	#echo -e "\n\t\tCAMBIOS DE CONTEXTO\n" 
	#echo -e "\t\t   PRO\t    CAMBIOS CONTEXTO  " 
	cambio_contexto=0
	for(( xp=0 ; xp < $num_proc ; xp++ ))
	do
		#echo -e "\t\t   ${PROC[$xp]}\t \t${CONTEXTO[$xp]}   "
		cambio_contexto=`expr ${cambio_contexto} + ${CONTEXTO[$xp]}`
	done
}

#Inicia una serie de datos de los procesos
iniciador_de_estados(){

	for(( xp=0 ; xp < $num_proc ; xp++ ))
	do
		ch_estado $xp 0 "iniciador_de_estados"
		ESTADOS_ANTERIORES[$xp]="" # Asuncion incial, sin estado ningun proceso
		EN_MEMO[$xp]="S/E"
		TIEMPO_EJEC[$xp]=0
		TIEMPO_PARADO[$xp]=0
		TIEMPO_FIN[$xp]=0
		WAIT[$xp]=0
		PART[$xp]=-1 #PART[] init
		PART_PRINT[$xp]=-1 #PART_PRINT[] init
		T_RETORNO[$xp]=0
		T_ESPERA[$xp]=0

	done
}


buscar_proceso_ejecucion(){
	#contador çde ejecuciones

	procesoEjec=-1
	for (( i=0 ; i < $num_proc ; i++ ))
	do
		if [[ "${ESTADO[$i]}" == "En Ejecucion" ]]; then
			procesoEjec=$i
		fi
	done

}

# Muestra la BT eactualizando su tamño dependiendo del tamaño de la ventana
mostrar_banda_tiempo(){

	ppartBT=0
	partBT=0
	tiempoActu=0
	primerSector=-2
	ultimoPorceso=-1
	barraBTextoColores=();
	barraBTextoProcesos=();
	barraBTextoColores_nc=();
	barraBTextoProcesos_nc=();
	barraBTextoTiempos=();
	j_e=0
	bpantalla=$[$(tput cols) - 1]
	bcarT=" BT |${barraBTextoColores_nc[$j_e]}"


	for partBT in ${!gl_array_tiempos[*]};do
		#echo "$partBT    ${PROC[${gl_array_tiempos[$partBT]}]}"

		bcarT=" BT |${barraBTextoColores_nc[$j_e]}"
		tiempoActu=`expr $partBT - 1`
		if [[ `expr ${#bcarT} + 3`  -ge $bpantalla ]]; then
			((j_e++))
		fi
		

		for ((i=0 ;  i < 3 ; i++ ))
		do

			if [[ ${gl_array_tiempos[$partBT]} -eq -1 ]]; then # Sin proceso	
				barraBTextoColores[$j_e]="${barraBTextoColores[$j_e]}${color_default}█$color_default" #$
				barraBTextoColores_nc[$j_e]="${barraBTextoColores_nc[$j_e]}_"
			else  # Con proceso
				proceso_BT=${PROC[${gl_array_tiempos[$partBT]}]}
				ultimoPorceso="${gl_array_tiempos[$partBT]}"
				barraBTextoColores[$j_e]="${barraBTextoColores[$j_e]}${BG_COLORS[$proceso_BT]}${COLORS[$proceso_BT]} $color_default"
				barraBTextoColores_nc[$j_e]="${barraBTextoColores_nc[$j_e]}X"
			fi

		done

		if [[  $primerSector -ne ${gl_array_tiempos[$partBT]}  &&  ${gl_array_tiempos[$partBT]} -ne -1 ]]; then

			proceso_BT=${PROC[${gl_array_tiempos[$partBT]}]}
			if [ $proceso_BT -lt 10 ];then
				barraBTextoProcesos[$j_e]="${barraBTextoProcesos[$j_e]}${PROC_COLORS[$proceso_BT]}P0${proceso_BT}${color_default}"
				barraBTextoProcesos_nc[$j_e]="${barraBTextoProcesos_nc[$j_e]}P0${proceso_BT}"
			else 
				barraBTextoProcesos[$j_e]="${barraBTextoProcesos[$j_e]}${PROC_COLORS[$proceso_BT]}P${proceso_BT}${color_default}"
					barraBTextoProcesos_nc[$j_e]="${barraBTextoProcesos_nc[$j_e]}P${proceso_BT}"
			fi

			if [[ $tiempoActu -le 9 ]];then 
				barraBTextoTiempos[$j_e]="${barraBTextoTiempos[$j_e]}  $tiempoActu"
			else 
				if [[ $tiempoActu -le 99 ]];then 
					barraBTextoTiempos[$j_e]="${barraBTextoTiempos[$j_e]} $tiempoActu"
				else 
					barraBTextoTiempos[$j_e]="${barraBTextoTiempos[$j_e]}$tiempoActu"
				fi
			fi
			primerSector=${gl_array_tiempos[$partBT]}
		else 

			if [[  $primerSector -ne ${gl_array_tiempos[$partBT]}  &&  ${gl_array_tiempos[$partBT]} -eq -1 ]]; then
				if [[ $tiempoActu -le 9 ]];then 
					barraBTextoTiempos[$j_e]="${barraBTextoTiempos[$j_e]}  $tiempoActu"
				else 
					if [[ $tiempoActu -le 99 ]];then 
						barraBTextoTiempos[$j_e]="${barraBTextoTiempos[$j_e]} $tiempoActu"
					else 
						barraBTextoTiempos[$j_e]="${barraBTextoTiempos[$j_e]}$tiempoActu"
					fi
				fi

				barraBTextoProcesos[$j_e]="${barraBTextoProcesos[$j_e]}   "
				barraBTextoProcesos_nc[$j_e]="${barraBTextoProcesos_nc[$j_e]}   "
				primerSector=${gl_array_tiempos[$partBT]}
			else 

				barraBTextoProcesos[$j_e]="${barraBTextoProcesos[$j_e]}   "
				barraBTextoProcesos_nc[$j_e]="${barraBTextoProcesos_nc[$j_e]}   "
				barraBTextoTiempos[$j_e]="${barraBTextoTiempos[$j_e]}   "

			fi 
		fi
		

		bcarT=" BT |${barraBTextoColores_nc[$j_e]}"
		if [[ `expr ${#bcarT} + 3`  -ge $bpantalla ]]; then
			((j_e++))
		fi
		#echo ${gl_array_tiempos[$partBT]}
	done 



	if [[ $partBtUltimo -ge 1 ]]; then 
		partBtUltimo=`expr $tiempo_transcurrido - 0 `
	else 
		partBtUltimo="$tiempo_transcurrido"
	fi 


	if [[ $partBtUltimo -eq 0 ]];then 
		barraBTextoTiempos[$j_e]="${barraBTextoTiempos[$j_e]}   "
	else 
		if [[ $partBtUltimo -le 9 ]];then 
			barraBTextoTiempos[$j_e]="${barraBTextoTiempos[$j_e]}  $partBtUltimo"
		else 
			if [[ $partBtUltimo -le 99 ]];then 
				barraBTextoTiempos[$j_e]="${barraBTextoTiempos[$j_e]} $partBtUltimo"
			else 
				barraBTextoTiempos[$j_e]="${barraBTextoTiempos[$j_e]}$partBtUltimo"
			fi
		fi
	fi 
	

	barraBTextoColores[$j_e]="${barraBTextoColores[$j_e]}   "
	barraBTextoColores_nc[$j_e]="${barraBTextoColores_nc[$j_e]}   "


	buscar_proceso_ejecucion

	if [[ $procesoEjec -ne -1 && $ultimoPorceso -ne $procesoEjec ]];then 
		proceso_BT=${PROC[$procesoEjec]}
		if [ $proceso_BT -lt 10 ];then
			barraBTextoProcesos[$j_e]="${barraBTextoProcesos[$j_e]}${PROC_COLORS[$proceso_BT]}P0${proceso_BT}${color_default}"
			barraBTextoProcesos_nc[$j_e]="${barraBTextoProcesos_nc[$j_e]}P0${proceso_BT}"
		else 
			barraBTextoProcesos[$j_e]="${barraBTextoProcesos[$j_e]}${PROC_COLORS[$proceso_BT]}P${proceso_BT}${color_default}"
				barraBTextoProcesos_nc[$j_e]="${barraBTextoProcesos_nc[$j_e]}P${proceso_BT}"
		fi
	else 
		barraBTextoProcesos[$j_e]="${barraBTextoProcesos[$j_e]}   "
		barraBTextoProcesos_nc[$j_e]="${barraBTextoProcesos_nc[$j_e]}   "
	fi 

	bcarT=" BT |${barraBTextoColores_nc[$j_e]}"
	if [[ `expr ${#bcarT} + 5`  -ge $bpantalla ]]; then
		((j_e++))
	fi

	barraBTextoTiempos[$j_e]="${barraBTextoTiempos[$j_e]}|"

	barraBTextoColores[$j_e]="${barraBTextoColores[$j_e]}|T=$partBtUltimo"
	barraBTextoProcesos[$j_e]="${barraBTextoProcesos[$j_e]}|"
	barraBTextoColores_nc[$j_e]="${barraBTextoColores_nc[$j_e]}|T=$partBtUltimo"
	barraBTextoProcesos_nc[$j_e]="${barraBTextoProcesos_nc[$j_e]}|"




	for (( i=0 ; i  <= $j_e ;i++ ))
	do

		echo -en "    |${barraBTextoProcesos[$i]}\n" 
		echo -en "    |${barraBTextoProcesos[$i]}\n" >> informeColor.txt
		echo -en "    |${barraBTextoProcesos_nc[$i]}\n" >> informeRR.txt

		if [[ $i -eq 0 ]];then
			echo -en " BT |${barraBTextoColores[$i]}\n" 
			echo -en " BT |${barraBTextoColores[$i]}\n" >> informeColor.txt
			echo -en " BT |${barraBTextoColores_nc[$i]}\n" >> informeRR.txt
		else 
			echo -en "    |${barraBTextoColores[$i]}\n" 
			echo -en "    |${barraBTextoColores[$i]}\n" >> informeColor.txt
			echo -en "    |${barraBTextoColores_nc[$i]}\n" >> informeRR.txt
		fi

		echo -en "    |${barraBTextoTiempos[$i]}\n" 
		echo -en "    |${barraBTextoTiempos[$i]}\n" >> informeColor.txt
		echo -en "    |${barraBTextoTiempos[$i]}\n" >> informeRR.txt

	done

	
}


#tabla que se va mostrando durante la ejecucion de los procesos
tabla_ejecucion(){
	en_memoria
	local return_time
	local t_ret
	local t_esp
	local part
	local raf_print
	local memoria_disponible
	local memoria_ocupada
	local procc
	local disponible
	local en_memoria
	local proc_column
	local ind_color
	local print
	
	instante=`expr $tiempo_transcurrido - $quantum`

	#echo "instante=$instante ($tiempo_transcurrido - $quantum)"
	if [[ $instante -lt 0 ]];then
		instante=0
	fi
	instante=$tiempo_transcurrido
	#print=$(printf " Ref \t Ttl   Tej  Mem  P.MEM  Trej  T.RET Tesp  EN MEM  ESTADO")
	#echo $print
	echo -e "\n RR-FNI-MEJOR "
	echo -e "\n RR-FNI-MEJOR " >> informeRR.txt
	echo -e "\n RR-FNI-MEJOR " >> informeColor.txt
		echo -ne " T = ${instante}   QUANTUM = $quantum "
		echo -ne " T = ${instante}   QUANTUM = $quantum " >> informeRR.txt
		echo -ne " T = ${instante}   QUANTUM = $quantum " >> informeColor.txt
		for ipar in ${!PART_SIZE[*]};do
			TAM_PART[$ipar]=${PART_SIZE[$ipar]}
			echo -n  "  PART $ipar = ${PART_SIZE[$ipar]}"
			echo -n  "  PART $ipar = ${PART_SIZE[$ipar]}" >> informeRR.txt
			echo -n  "  PART $ipar = ${PART_SIZE[$ipar]}" >> informeColor.txt
		done
	echo -e "\n ------------------------------------------------------------------------"
	echo -e "\n ------------------------------------------------------------------------" >> informeRR.txt
	echo -e "\n ------------------------------------------------------------------------" >> informeColor.txt
	
	echo " | Ref | Tll | Tej | Mem | Tesp | Tret | Trej | Part |       ESTADO     |"
	echo " | Ref | Tll | Tej | Mem | Tesp | Tret | Trej | Part |       ESTADO     |" >> informeRR.txt
	echo " | Ref | Tll | Tej | Mem | Tesp | Tret | Trej | Part |       ESTADO     |" >> informeColor.txt

	
	echo  " ------------------------------------------------------------------------"
	echo  " ------------------------------------------------------------------------" >> informeRR.txt
	echo  " ------------------------------------------------------------------------" >> informeColor.txt
	
	for(( xp=0 ; xp < $num_proc ; xp++ ))
	do
		if [ ${PART[$xp]} -eq -1 ] # esta particion esta libre
		then
			part=" - "
		else
			let part=PART[xp]
		fi
		
		if [  ${PROC[$xp]} -lt 10 ];then
		
			proc_column="P0${PROC[$xp]}"
		else
			proc_column="P${PROC[$xp]}"
		fi	
		raf_print=${TIEMPO[$xp]}
		if [[ ${ESTADO[$xp]} == "Fuera de Sistema" || ${ESTADO[$xp]} == "En Espera" ]];then
			raf_print="- "
		fi
		if [[ ${TIEMPO[$xp]} -lt 1 ]]; then
			raf_print="- "
		fi


	
	
		printf " | ${PROC_COLORS[${PROC[$xp]}]}%3s${PROC_COLORS[${PROC[$xp]}]} \e\033[0;37m|\e[0m${PROC_COLORS[${PROC[$xp]}]} %3s${PROC_COLORS[${PROC[$xp]}]} \e\033[0;37m|\e[0m${PROC_COLORS[${PROC[$xp]}]} %3s \e\033[0;37m|\e[0m${PROC_COLORS[${PROC[$xp]}]} %3s \e\033[0;37m|\e[0m${PROC_COLORS[${PROC[$xp]}]}" $proc_column ${T_ENTRADA[$xp]} ${RAFAGA_AUX[$xp]} ${MEMORIA[$xp]}
		printf " | %3s | %3s | %3s | %3s |" $proc_column ${T_ENTRADA[$xp]} ${RAFAGA_AUX[$xp]} ${MEMORIA[$xp]} >> informeRR.txt 
		printf " | ${PROC_COLORS[${PROC[$xp]}]}%3s${PROC_COLORS[${PROC[$xp]}]} \e\033[0;37m|\e[0m${PROC_COLORS[${PROC[$xp]}]} %3s${PROC_COLORS[${PROC[$xp]}]} \e\033[0;37m|\e[0m${PROC_COLORS[${PROC[$xp]}]} %3s \e\033[0;37m|\e[0m${PROC_COLORS[${PROC[$xp]}]} %3s \e\033[0;37m|\e[0m${PROC_COLORS[${PROC[$xp]}]}" $proc_column ${T_ENTRADA[$xp]} ${RAFAGA_AUX[$xp]} ${MEMORIA[$xp]} >> informeColor.txt
		
	
		t_ret=${T_RETORNO[$xp]} #`expr ${TIEMPO_FIN[$xp]} - ${T_ENTRADA[$xp]}`
		t_esp=${T_ESPERA[$xp]} #`expr ${TIEMPO_FIN[$xp]} - ${T_ENTRADA[$xp]} - ${PROCESOS_I[$xp]}`
		if [[ $t_ret == "" ]];then
			t_ret=" - "
		fi
		if [[ $t_esp == "" ]];then
			t_esp=" - "
		fi
		
		if [ $t_ret -lt 0 ]
		then
			t_ret="N/A"
		fi
		if [ $t_esp -lt 0 ]
		then
			t_esp="N/A"
		fi
		if [ "${ESTADO[$xp]}" == "Finalizado" ];then
			return_time=`expr ${TIEMPO_FIN[$xp]} - ${T_ENTRADA[$xp]}`
		elif [ "${ESTADO[$xp]}" == "En Ejecucion" ] || [ "${ESTADO[$xp]}" == "En Espera" ] || [ "${ESTADO[$xp]}" == "En pausa" ];then
			return_time=`expr $tiempo_transcurrido - ${T_ENTRADA[$xp]}`
		else
			return_time=0
		fi

		if [[ ${ESTADO[$xp]} == "Fuera de Sistema" ]];then
			t_esp=" - "
			t_ret=" - "
		fi

		printf " %4s \e\033[0;37m|\e[0m${PROC_COLORS[${PROC[$xp]}]} %4s \e\033[0;37m|\e[0m${PROC_COLORS[${PROC[$xp]}]} %4s \e\033[0;37m|\e[0m${PROC_COLORS[${PROC[$xp]}]} %4s \e\033[0;37m|\e[0m" $t_esp $t_ret $raf_print $part
		printf " %4s | %4s | %4s | %4s |" $t_esp $t_ret $raf_print $part >> informeRR.txt
		printf " %4s \e\033[0;37m|\e[0m${PROC_COLORS[${PROC[$xp]}]} %4s \e\033[0;37m|\e[0m${PROC_COLORS[${PROC[$xp]}]} %4s \e\033[0;37m|\e[0m${PROC_COLORS[${PROC[$xp]}]} %4s \e\033[0;37m|\e[0m" $t_esp $t_ret $raf_print $part >> informeColor.txt
		 
		if [[ ${PART[$xp]} -gt -1 ]];then
			en_memoria="Si"
		else
			en_memoria="No"
		fi
		printf "${PROC_COLORS[${PROC[$xp]}]} %-16s \e\033[0;37m|\e[0m" "${ESTADO[$xp]}"
		printf " %-16s${color_defaul} |\n" "${ESTADO[$xp]}" >> informeRR.txt
		printf "${PROC_COLORS[${PROC[$xp]}]} %-16s \e\033[0;37m|\e[0m\n" "${ESTADO[$xp]}" >> informeColor.txt
	
		echo "" # Break line after last printf
		if [[ 1 == 0 ]];then

			echo -ne "\t${en_memoria}${color_default}\t"
			echo -ne "\t"
			
			case "${ESTADO[$xp]}" in
				"Finalizado" ) 
					echo -e "${ESTADO[$xp]}"
				;;
				"En Ejecucion" ) 
					echo -e "${ESTADO[$xp]}"
				;;
				"Sin Memoria" ) 
					echo -e "${ESTADO[$xp]}"
				;;
				"En pausa" ) 
					echo -e "${ESTADO[$xp]}"
				;;
				* ) 
					echo -e "${ESTADO[$xp]}"
				;;
			esac
		fi		

	done

	echo -e "\e\033[0;37m ------------------------------------------------------------------------\e[0m"
	echo  " ------------------------------------------------------------------------" >> informeRR.txt
	echo  " ------------------------------------------------------------------------" >> informeColor.txt
	
	T_MEDIO_R=0
	T_MEDIO_E=0
	for(( xp=0 ; xp < $num_proc ; xp++ ))
		do	
			if [ "${ESTADO[$xp]}" == "Bloqueado" ]
			then
				T_RETORNO[$xp]=0
				T_ESPERA[$xp]=0			
			fi
			t_espera=${T_ESPERA[$xp]}

			if [[ ${T_ESPERA[$xp]} -lt 0 ]];then
				t_espera="N/A"
				T_ESPERA[$xp]=0
			fi
			if [[ ${T_RETORNO[$xp]} -lt 0 ]];then
				T_RETORNO[$xp]=0
			fi
			T_MEDIO_R=`expr $T_MEDIO_R + ${T_RETORNO[$xp]}`
			T_MEDIO_E=`expr $T_MEDIO_E + ${T_ESPERA[$xp]}`

			#echo -ne $T_MEDIO_E
			#echo -e $T_MEDIO_R
			#echo -e "\t\t    ${PROC[$xp]}\t \t${T_RETORNO[$xp]}\t \t${t_espera}"
		done
	contadorProcesosMemoria=0	
	for(( i=1 ; i <= $num_proc ; i++ ))
		do
			if [[  "${ESTADO[$i]}" != "Fuera de Sistema"  ]]; then
				((contadorProcesosMemoria++))
			fi
		done
	espera=$(echo "scale = 2; $T_MEDIO_E/$contadorProcesosMemoria"| bc)	
	retorno=$(echo "scale = 2; $T_MEDIO_R/$contadorProcesosMemoria"| bc )
	#echo -ne "${color_default} Tiempo medio de espera: $espera \tTiempo medio de retorno: $retorno\n"
	

	echo -ne "${color_default} Tiempo medio de espera: "
	echo "$espera" | awk '{printf("%.2f",$1)}'
	echo -ne "\tTiempo medio de retorno: "
	echo "$retorno" | awk '{printf("%.2f",$1)}'
	echo -ne "\n"
	

	echo -ne " Tiempo medio de espera: $espera \tTiempo medio de retorno: $retorno\n" >> informeRR.txt
	echo -ne "${color_default} Tiempo medio de espera: $espera \tTiempo medio de retorno: $retorno\n" >> informeColor.txt

	#comprobamos si hay algún cambio de contexto.
	detecta_cambio_estados

	#procesos en cola de ejecución
	echo -n " Procesos en cola de Round-Robin: "
	echo -n " Procesos en cola de Round-Robin: " >> informeRR.txt
	echo -n " Procesos en cola de Round-Robin: " >> informeColor.txt

	#contador de ejecuciones
	for (( i=0 ; i < $num_proc ; i++ ))
	do
		if [[ "${ESTADO[$i]}" == "En Ejecucion" ]] && [[ $gl_cambio_ejecucion -eq 1 ]]; then
			contador_ejecuciones[$i]=$((${contador_ejecuciones[$i]} + 1))
			if [[ ${contador_ejecuciones[$i]} -gt $max_ejecuciones ]]; then
				max_ejecuciones=${contador_ejecuciones[$i]}
			fi
		fi
	done
	#imprime la cola de procesos
	for (( i=0 ; i <= $max_ejecuciones ; i++ ))
	do
		for(( x=0 ; x < $num_proc ; x++ ))
		do

			if [[ "${ESTADO[$x]}" == "En Memoria" ]] || [[ "${ESTADO[$x]}" == "En Pausa" ]]; then
				if [[ ${contador_ejecuciones[$x]} -eq $i ]] && [[ ${encolado[$x]} -eq 1 ]]; then
					if [[ ${PROC[$x]} -lt 10 ]]; then
						echo -ne "${PROC_COLORS[${PROC[$x]}]}P0${PROC[$x]}$color_default "
						echo -ne "P0${PROC[$x]} " >> informeRR.txt
						echo -ne "${PROC_COLORS[${PROC[$x]}]}P0${PROC[$x]}$color_default " >> informeColor.txt
					else
						echo -ne "${PROC_COLORS[${PROC[$x]}]}P${PROC[$x]}$color_default "
						echo -ne "P${PROC[$x]} " >> informeRR.txt
						echo -ne "${PROC_COLORS[${PROC[$x]}]}P${PROC[$x]}$color_default " >> informeColor.txt
					fi
				fi
			fi
		done
	done
	for (( i=0 ; i <= $max_ejecuciones ; i++ ))
	do
		for(( x=0 ; x < $num_proc ; x++ ))
		do
			if [[ "${ESTADO[$x]}" == "En Memoria" ]] || [[ "${ESTADO[$x]}" == "En Pausa" ]]; then
				if [[ ${contador_ejecuciones[$x]} -eq $i ]] && [[ ${encolado[$x]} -eq 0 ]]; then
					if [[ ${PROC[$x]} -lt 10 ]]; then
						echo -ne "${PROC_COLORS[${PROC[$x]}]}P0${PROC[$x]}$color_default "
						echo -ne "P0${PROC[$x]} " >> informeRR.txt
						echo -ne "${PROC_COLORS[${PROC[$x]}]}P0${PROC[$x]}$color_default " >> informeColor.txt
					else
						echo -ne "${PROC_COLORS[${PROC[$x]}]}P${PROC[$x]}$color_default "
						echo -ne "P${PROC[$x]} " >> informeRR.txt
						echo -ne "${PROC_COLORS[${PROC[$x]}]}P${PROC[$x]}$color_default " >> informeColor.txt
					fi
				fi
			fi
		done
	done
	#contador de procesos que estaban ya en la cola
	for (( i=0 ; i < $num_proc ; i++ ))
	do
		if [[ "${ESTADO[$i]}" == "En Memoria" ]] || [[ "${ESTADO[$i]}" == "En Pausa" ]]|| [[ "${ESTADO[$i]}" == "En Ejecucion" ]]; then
			encolado[$i]=1
		else
			encolado[$i]=0
		fi
	done

	echo ""
	echo "" >>informeRR.txt
	echo "" >> informeColor.txt
	
	prt=0
	fg_color_blanco="\e[107m"
	fg_color_red="\e[91m"
	espacio=" "
	disponible=0
	sumaParticiones=0
	j=0
	#variables para medir el tamaño del terminal
	bcar="${barraMem_nc[$j]}"
	bpantalla=$[$(tput cols) - 1]
	tamanoPartBarra=0
	primerSector=0
	utlimoSector=0
	

	for ppart in ${!TAM_PART[*]};do
		if [ $prt -eq 0 ];then
			((prt++))
		fi
		#echo ${#bcar}
		bcar=" BM |${barraMem_nc[$j]}"
		primerSector=0
		if [[ ( `expr ${#bcar} + 7` -ge $bpantalla && $primerSector -eq 0 ) || ( ${#bcar}  -ge $bpantalla && $primerSector -eq 1 )   ]]; then
			((j++))
		fi

		cntparti=0		
		buscar_indice_memoria $ppart
		memoria_disponible=`expr ${TAM_PART[$ppart]}`
		# Priemra parte: Imprime el numero de proceso que ocupa pero en color
		if [[ $ind_part_ocupada -ge 0 ]];then
			#echo "Refrescamos memoria_disponible, para la particion ind $ppart, TAM_PART es ${TAM_PART[$ppart]} y MEMORIA del indice $ind_part_ocupada es ${MEMORIA[$ind_part_ocupada]}"
			memoria_disponible=`expr ${TAM_PART[$ppart]} - ${MEMORIA[$ind_part_ocupada]}`
			procc=${PROC[$ind_part_ocupada]}
			if [ $procc -lt 10 ];then
				#echo -ne "${PROC_COLORS[$procc]}P0${procc}${color_default} "
				barraProceso[$j]="${barraProceso[$j]}${PROC_COLORS[$procc]} P0${procc}${color_default}    "
				barraProceso_nc[$j]="${barraProceso_nc[$j]} P0${procc}    "
			else
				#echo -ne "${PROC_COLORS[$procc]}P${procc}${color_default} "
				barraProceso[$j]="${barraProceso[$j]}${PROC_COLORS[$procc]} P${procc}${color_default}    "
				barraProceso_nc[$j]="${barraProceso_nc[$j]} P${procc}    "
			fi
			memoria_ocupada=${MEMORIA[$ind_part_ocupada]}
		else
			#echo -n "NA  "
			nada="        "
			if [[ $ppart -eq 0 ]]; then
				barraProceso[$j]="${barraProceso[$j]}        "
			else
				barraProceso[$j]="${barraProceso[$j]}        "
			fi
			#barraProceso[$j]="${barraProceso[$j]}"
			barraProceso_nc[$j]="${barraProceso_nc[$j]}$nada"
			memoria_ocupada=0
		fi

		if [[ $memoria_ocupada -gt 0 ]];then

			#Sistema  muy antiguo, la parte ocupada siempre en rojo puro echo -en "${bg_color_red}"
			#Sistema antiguo, la parte ocupada con el mismo color del proceso
			#sistema nuevo, memoria lineal con valores ascendentes y fondo blanco.
					#commprueba en cada carácter el tamaño de la barra
			barraMem[$j]="${barraMem[$j]}${BG_COLORS[$procc]}${COLORS[$procc]}"
			tamanoPartBarra=$(($tamanoPartBarra + 1))
			
			
			#cuando el proceso ocupa la partición de memoria
			while [ $memoria_ocupada -gt $cntparti ];do
				bcar=" BM |${barraMem_nc[$j]}"
				if [[ ( `expr ${#bcar} + 7` -ge $bpantalla && $primerSector -eq 0 ) || ( ${#bcar}  -ge $bpantalla && $primerSector -eq 1 )   ]]; then
					((j++))
				fi
				bcar=" BM |${barraMem_nc[$j]}"
				for ((i=0 ;  i < 8 ; i++ ))
				do
				
					bcar=" BM |${barraMem_nc[$j]}"
					if [[ ( ${#bcar}  -ge $bpantalla && $primerSector -eq 1 )   ]]; then
						((j++))
					fi
					

					barraMem[$j]="${barraMem[$j]}${BG_COLORS[$procc]}${COLORS[$procc]} $color_default"
					barraMem_nc[$j]="${barraMem_nc[$j]}X"

					
					
					if [[ $cntparti -ge 1 ]]; then
						barraTam[$j]="${barraTam[$j]} "
						barraNumPart[$j]="${barraNumPart[$j]} "
					fi
					
					if [[ $cntparti -lt 1 ]]; then
						barraProceso[$j]="${barraProceso[$j]}"
					else
						barraProceso[$j]="${barraProceso[$j]} "
						barraProceso_nc[$j]="${barraProceso_nc[$j]} "
					fi
					bcar=" BT |${barraMem_nc[$j]}"
					if [[  ( ${#bcar}  -ge $bpantalla && $primerSector -eq 1 )   ]]; then
						((j++))
					fi
				done
				((cntparti++))
				primerSector=1
				parteOcupada=$cntparti
			done

			bcar=" BT |${barraMem_nc[$j]}"
			if [[ ( `expr ${#bcar} + 7` -ge $bpantalla && $primerSector -eq 0 ) || ( ${#bcar}  -ge $bpantalla && $primerSector -eq 1 )   ]]; then
				((j++))
			fi

			disponible=$(($sumaParticiones +$cntparti))
			if [[ $parteOcupada -ne ${TAM_PART[$ppart]} ]]; then
				if [[ $disponible -lt 10 ]]; then
					barraTam[$j]="${barraTam[$j]}$disponible "
					barraNumPart[$j]="${barraNumPart[$j]} "
				else
					barraTam[$j]="${barraTam[$j]}$disponible"
					barraNumPart[$j]="${barraNumPart[$j]}"
				fi
			fi
			#cuando el proceso no rellena toda la partición y pinta de blanco el espacio restante
			barraMem[$j]="${barraMem[$j]}${color_default}"
			barraMem[$j]="${barraMem[$j]}${fg_color_blanco}"
			iteracionRellenar=0
			while [ $cntparti -lt ${TAM_PART[$ppart]} ];do
				bcar=" BT |${barraMem_nc[$j]}"
				if [[ ( `expr ${#bcar} + 7` -ge $bpantalla && $primerSector -eq 0 ) || ( ${#bcar}  -ge $bpantalla && $primerSector -eq 1 )   ]]; then
					((j++))
				fi
				bcar=" BT |${barraMem_nc[$j]}"
				for ((i=0 ;  i < 8 ; i++ ))
				do 
					bcar=" BM |${barraMem_nc[$j]}"
					if [[  ( ${#bcar}  -ge $bpantalla && $primerSector -eq 1 )   ]]; then
						((j++))
					fi

					barraMem[$j]="${barraMem[$j]}${color_default}█$color_default"
					barraMem_nc[$j]="${barraMem_nc[$j]}_"
					if [[ $cntparti -lt $((memoria_ocupada)) ]]; then
						barraTam[$j]="${barraTam[$j]}" 
						barraNumPart[$j]="${barraNumPart[$j]}" 
					else
						iteracionRellenar=$((iteracionRellenar+1))
						if [[ $iteracionRellenar -ge 3 ]]; then
							barraTam[$j]="${barraTam[$j]} "
						fi
					fi
					if [[ $cntparti -ge 1 ]]; then
					
						#barraTam[$j]="${barraTam[$j]}?"
						barraNumPart[$j]="${barraNumPart[$j]} "
						barraProceso[$j]="${barraProceso[$j]} "
						barraProceso_nc[$j]="${barraProceso_nc[$j]} "
					fi

					bcar=" BT |${barraMem_nc[$j]}"
					if [[ ( ${#bcar}  -ge $bpantalla && $primerSector -eq 1 )   ]]; then
						((j++))
					fi
				done
				((cntparti++))
				primerSector=1
			done
			
			
		else
			###############################################
			#cuando la partición no contiene ningún proceso
			###############################################
			barraMem[$j]="${barraMem[$j]}${fg_color_blanco}"
			tamanoPartBarra=$(($tamanoPartBarra + 1))
		

			while [ $memoria_disponible -gt $cntparti ];do

				bcar=" BT |${barraMem_nc[$j]}"
				if [[ ( `expr ${#bcar} + 7` -ge $bpantalla && $primerSector -eq 0 ) || ( ${#bcar}  -ge $bpantalla && $primerSector -eq 1 )   ]]; then
					((j++))
				fi
				bcar=" BT |${barraMem_nc[$j]}"
				for ((i=0 ;  i < 8 ; i++ ))
				do

					
					bcar=" BM |${barraMem_nc[$j]}"
					if [[ ( ${#bcar}  -ge $bpantalla && $primerSector -eq 1 )   ]]; then
						((j++))
						
				
					fi

					barraMem[$j]="${barraMem[$j]}${color_default}█$color_default" #${fg_color_blanco}
					barraMem_nc[$j]="${barraMem_nc[$j]}_"
					if [[ $cntparti -ge 1 ]]; then
						barraTam[$j]="${barraTam[$j]} " 
						barraNumPart[$j]="${barraNumPart[$j]} "
					fi
					if [[ $cntparti -lt 1 ]]; then
						barraProceso[$j]="${barraProceso[$j]}"
					else
						barraProceso_nc[$j]="${barraProceso_nc[$j]} "
						barraProceso[$j]="${barraProceso[$j]} "
					fi
					
					bcar=" BT |${barraMem_nc[$j]}"
					if [[ ( ${#bcar}  -ge $bpantalla && $primerSector -eq 1 )   ]]; then
						((j++))
						
					fi
				done
				((cntparti++))
				primerSector=1
			done
			disponible=$(($sumaParticiones +$cntparti))
			
			

			printCab=0
			while [ $cntparti -lt ${TAM_PART[$ppart]} ];do
				if [[ ( `expr ${#bcar} + 7` -ge $bpantalla && $primerSector -eq 0 ) || ( ${#bcar}  -ge $bpantalla && $primerSector -eq 1 )   ]]; then
					((j++))
				fi
				bcar=" BT |${barraMem_nc[$j]}"
				for ((i=0 ;  i < 8 ; i++ ))
				do
					bcar=" BM |${barraMem_nc[$j]}"
					if [[ ( ${#bcar}  -ge $bpantalla && $primerSector -eq 1 )   ]]; then
						((j++))
					fi

					
					barraMem[$j]="${barraMem[$j]}█"
					barraMem_nc[$j]="${barraMem_nc[$j]}_"
					if [[ $cntparti -ge 1 ]]; then 
						barraTam[$j]="${barraTam[$j]} "
						barraNumPart[$j]="${barraNumPart[$j]} "
					fi
					if [[ $cntparti -lt 1 ]]; then
						barraProceso[$j]="${barraProceso[$j]}"
					else
						barraProceso[$j]="$barraProceso[$j]} "
						barraProceso_nc[$j]="${barraProceso_nc[$j]} "
					fi

					bcar=" BT |${barraMem_nc[$j]}"
					if [[ ( ${#bcar}  -ge $bpantalla && $primerSector -eq 1 )   ]]; then
					
						((j++))
					fi
				done
				((cntparti++))
				primerSector=1


				
			done

			

				
		fi

		bcar=" BT |${barraMem_nc[$j]}"
		if [[ ( `expr ${#bcar} + 7` -ge $bpantalla && $primerSector -eq 0 ) || ( ${#bcar}  -ge $bpantalla && $primerSector -eq 1 )   ]]; then
			
			((j++))
			
		fi
		#separación entre particiones
		barraMem[$j]="${barraMem[$j]}\e[48;5;16m|$color_default"
		
		bcar=" BT |${barraMem_nc[$j]}"
		
		if [[ $ppart -eq ${#TAM_PART[*]}-1 ]]; then 
			utlimoSector=1
			if [[ `expr ${#bcar} + 5` -ge $bpantalla   ]]; then
				
				((j++))
				
			fi
			barraTam[$j]="${barraTam[$j]}|"
			barraNumPart[$j]="${barraNumPart[$j]}|"
			barraProceso[$j]="${barraProceso[$j]}|"
			barraProceso_nc[$j]="${barraProceso_nc[$j]}|"
			barraMem_nc[$j]="${barraMem_nc[$j]}|"
		else
			barraTam[$j]="${barraTam[$j]} "
			barraNumPart[$j]="${barraNumPart[$j]} "
			barraProceso[$j]="${barraProceso[$j]} "
			barraProceso_nc[$j]="${barraProceso_nc[$j]} "
			barraMem_nc[$j]="${barraMem_nc[$j]}|"
		fi


		bcar=" BT |${barraMem_nc[$j]}"
		primerSector=0
		if [[ utlimoSector -eq 0 && ( `expr ${#bcar} + 7` -ge $bpantalla && $primerSector -eq 0 ) || ( ${#bcar}  -ge $bpantalla && $primerSector -eq 1 )   ]]; then
			
			((j++))
			
		fi

		sumaParticiones=0
		for(( xp=0 ; xp <= $ppart ; xp++ ))
		do
			sumaParticiones=$(($sumaParticiones + ${TAM_PART[$xp]}))
		done

		if [[ $sumaParticiones -lt 10 ]]; then
			if [[ $n_par -ne $((ppart + 1)) ]]; then
				barraTam[$j]="${barraTam[$j]}  $sumaParticiones     "
				primerSector=1
			fi
		else
			if [[ $n_par -ne $((ppart +1)) ]]; then
				barraTam[$j]="${barraTam[$j]}  $sumaParticiones    "
				primerSector=1
			fi
		fi


		if [[ $tamanoPartBarra -lt 10 ]]; then
			if [[ $n_par -ne $((ppart + 1)) ]]; then
				barraNumPart[$j]="${barraNumPart[$j]}PART $tamanoPartBarra  "
				primerSector=1
			fi
		else
			if [[ $n_par -ne $((ppart +1)) ]]; then
				barraNumPart[$j]="${barraNumPart[$j]}PART $tamanoPartBarra "
				primerSector=1
			fi
		fi
	done

	


	#sistema para la impresión de la banda de memoria   <= $j
	for (( i=0 ; i  <= $j ;i++ ))
	do
		
		

		if [[ $i -eq 0 ]]; then
			if [[ $i -eq $j ]]; then
				echo -en "    |${barraProceso[$i]}\n" 
				echo -en "    |${barraProceso_nc[$i]}\n" >> informeRR.txt
				echo -en "    |${barraProceso[$i]}\n" >>informeColor.txt
			else
				echo -en "    |${barraProceso[$i]}\n" 
				echo -en "    |${barraProceso_nc[$i]}\n" >> informeRR.txt
				echo -en "    |${barraProceso[$i]}\n" >>informeColor.txt
			fi
		else
			if [[ $i -eq $j ]]; then
				echo -en "    |${barraProceso[$i]}\n"
				echo -en "    |${barraProceso_nc[$i]}\n" >> informeRR.txt
				echo -en "    |${barraProceso[$i]}\n" >>informeColor.txt
			else
				echo -en "    |${barraProceso[$i]}\n"
				echo -en "    |${barraProceso_nc[$i]}\n" >> informeRR.txt
				echo -en "    |${barraProceso[$i]}\n" >>informeColor.txt
			fi
		fi

		if [[ $i -eq 0 ]]; then
			if [[ $i -eq $j ]]; then
				echo -en "    |PART 0  ${barraNumPart[$i]}$color_default\n"
				echo -en "    |PART 0  ${barraNumPart[$i]}\n" >> informeRR.txt
				echo -en "    |PART 0  ${barraNumPart[$i]}$color_default\n" >> informeColor.txt
			else
				echo -en "    |PART 0  ${barraNumPart[$i]}$color_default\n"
				echo -en "    |PART 0  ${barraNumPart[$i]}\n" >> informeRR.txt
				echo -en "    |PART 0  ${barraNumPart[$i]}$color_default\n" >> informeColor.txt
			fi
		else
			if [[ $i -eq $j ]]; then
				echo -en "    |${barraNumPart[$i]}\n"
				echo -en "    |${barraNumPart[$i]}\n" >> informeRR.txt
				echo -en "    |${barraNumPart[$i]}$color_default\n" >> informeColor.txt
			else
				echo -en "    |${barraNumPart[$i]}\n"
				echo -en "    |${barraNumPart[$i]}\n" >> informeRR.txt
				echo -en "    |${barraNumPart[$i]}$color_default\n" >> informeColor.txt
			fi
		fi

		if [[ $i -eq $j ]]; then

			if [[ $i -eq 0 ]]; then
				echo -en " BM |${barraMem[$i]}${color_default}M=$sumaParticiones\n"
				echo -en " BM |${barraMem_nc[$i]}M=$sumaParticiones\n" >> informeRR.txt
				echo -en " BM |${barraMem[$i]}${color_default}M=$sumaParticiones\n" >> informeColor.txt
			else
				echo -en "    |${barraMem[$i]}${color_default}M=$sumaParticiones\n"
				echo -en "    |${barraMem_nc[$i]}M=$sumaParticiones\n" >> informeRR.txt
				echo -en "    |${barraMem[$i]}${color_default}M=$sumaParticiones\n" >> informeColor.txt
			fi

		else
			if [[ $i -eq 0 ]]; then
				echo -en " BM |${barraMem[$i]}${color_default}\n"
				echo -en " BM |${barraMem_nc[$i]}\n" >> informeRR.txt
				echo -en " BM |${barraMem[$i]}${color_default}\n" >> informeColor.txt
			else
				echo -en "    |${barraMem[$i]}${color_default}\n"
				echo -en "    |${barraMem_nc[$i]}\n" >> informeRR.txt
				echo -en "    |${barraMem[$i]}${color_default}\n" >> informeColor.txt
			fi

		fi
		#echo -en "    |${barraProceso_nc[$i]}\n" >> informeRR.txt
		#echo -en " BM |${barraMem_nc[$i]}\n" >> informeRR.txt
		#echo -en "    |${barraProceso[$i]}\n" >>informeColor.txt
		#echo -en " BM |${barraMem[$i]}${color_default}\n" >> informeColor.txt
		if [[ $i -eq 0 ]]; then
			if [[ $i -eq $j ]]; then
				echo -en "    |  0     ${barraTam[$i]}$color_default \n"
				echo -en "    |  0     ${barraTam[$i]}\n" >> informeRR.txt
				echo -en "    |  0     ${barraTam[$i]}$color_default\n" >> informeColor.txt
			else
				echo -en "    |  0     ${barraTam[$i]}$color_default\n"
				echo -en "    |  0     ${barraTam[$i]}\n" >> informeRR.txt
				echo -en "    |  0     ${barraTam[$i]}$color_default\n" >> informeColor.txt
			fi
		else
			if [[ $i -eq $j ]]; then
				echo -en "    |${barraTam[$i]}$color_default\n"
				echo -en "    |${barraTam[$i]}\n" >> informeRR.txt
				echo -en "    |${barraTam[$i]}$color_default\n" >> informeColor.txt
			else
				echo -en "    |${barraTam[$i]}$color_default\n"
				echo -en "    |${barraTam[$i]}\n" >> informeRR.txt
				echo -en "    |${barraTam[$i]}$color_default\n" >> informeColor.txt
			fi
		fi

	
			
	done

	mostrar_banda_tiempo
	echo ""
	echo ""
	echo ""
	
	#exit 
	for (( i=0 ; i <= $j ;i++ ))
	do
	barraMem[$i]=""
	barraNumPart[$i]=""
	barraTam[$i]=""
	barraProceso[$i]=""
	barraMem_nc[$i]=""
	barraProceso_nc[$i]=""
	done


	instante=`expr $tiempo_transcurrido - $quantum`

	if [[ $instante -lt 0 ]];then
		instante=0
	fi
	instante=$tiempo_transcurrido
	if [[ $gl_proc_ejec -gt -1 ]];then
		(( ind_color=$gl_proc_ejec+1 ))

	fi
	#comprueba si algún proceso entra al inicio.
	inst0=0	
	for(( i=0 ; i < $num_proc ; i++ ))
	do
		if [[  "${T_ENTRADA[$i]}" -lt 1  ]]; then
			((inst0++))
			break
		fi
	done


	
		

}

#mete los datos sobre las particiones y el quantum obtenidos del fichero en el informe
datos_fichTfich() {
	echo -e "\t\t>> Numero de particiones: $n_par" >> informeRR.txt
	echo -e "\t\t>> Numero de particiones: $n_par" >> informeColor.txt  
	nparti=0
	while [ $n_par -gt $nparti ];do
		echo -e "\t\t\t>> Tamaño particion $nparti: ${PART_SIZE[$nparti]}" >> informeRR.txt
		echo -e "\t\t\t>> Tamaño particion $nparti: ${PART_SIZE[$nparti]}" >> informeColor.txt
		((nparti++))
	done
	echo "		>> Quantum de tiempo: $quantum" >> informeRR.txt
	echo "		>> Quantum de tiempo: $quantum" >> informeColor.txt

}

# Pide los datos de la memoria del sistema
#modificado para que siga el mismo sistema que los procesos
pedir_memoria() {
	local ac
	contPart=0
	option="s"
	n_par=0
	#se elimina el número de particiones
	#Se introducen de la misma manera que los procesos
	while [[ $option == "s" ]];
	do
		read -p " Introduzca el tamaño de la partición [`expr $contPart + 1`]: " tam_par
		
		while ! mayor_cero $tam_par;do
			echo " Entrada no válida, debe ser mayor que 0"
        	read -p " Introduzca tamaño de la partición [`expr $contPart + 1`]: " tam_par
		done

		let PART_SIZE[$contPart]=$tam_par
		let TAM_PART[$contPart]=$tam_par
		let n_par=`expr $n_par + 1`
		((contPart++))

		read -p " ¿ Desea añadir más particiones? (s/n): " option
	done
	
	#meter la informacion sobre la memoria en el informe
	echo "		>> Numero de particiones: $n_par" >> informeRR.txt
	echo "		>> Numero de particiones: $n_par" >> informeColor.txt
	o=`expr 0`
	k=`expr 1`
	while [ $o -lt $n_par ]
	do
		echo -e "\t\t\t>> Tamaño de particion ${k}: ${PART_SIZE[$o]}" >> informeRR.txt
		echo -e "\t\t\t>> Tamaño de particion ${k}: ${PART_SIZE[$o]}" >> informeColor.txt
		((o++))
		((k++))
	done

}

# Pide los rangos de la memoria del sistema 
# guarda los valores en el archivo "fich_random_cfg"
pedir_procesos_rangos() {

	local leer_dato_usuario
	local textos_pedidato
	 declare -A min_num
	 declare -A max_num

	local bucle_pedir_num

	textos_pedidato[0]=" Introduzca el rango de numero de procesos  (Ej: 1-10): "
	textos_pedidato[1]=" Introduzca el rango de tiempo de llegada de procesos  (Ej: 4-10): "
	textos_pedidato[2]=" Introduzca el rango de rafaga de procesos  (Ej: 2-16): "
	textos_pedidato[3]=" Introduzca el rango de memoria de procesos  (Ej: 2-7): "

	min_num[0,0]=-1
	max_num[0,1]=-1
	min_num[1,0]=-1
	max_num[1,1]=-1
	min_num[2,0]=-1
	max_num[2,1]=-1
	min_num[3,0]=-1
	max_num[3,1]=-1

	count=0
	while [ $count -le 3 ]
	do
		bucle_pedir_num=-1

		while  [ $bucle_pedir_num == -1 ] ;
		do
			
			read -p "${textos_pedidato[$count]}" leer_dato_usuario
			echo "		  ${textos_pedidato[$count]}" >> informeRR.txt
			echo "		  ${textos_pedidato[$count]}" >> informeColor.txt

			echo "		    > Teclado: $leer_dato_usuario" >> informeRR.txt
			echo "		    > Teclado: $leer_dato_usuario" >> informeColor.txt

			
			if [[ "$leer_dato_usuario" == *"-"* ]]; 
			then

				arrIN=(${leer_dato_usuario//-/ })
				min_num[$count,0]=${arrIN[0]} 
				max_num[$count,1]=${arrIN[1]} 

				if	 [ ${min_num[$count,0]} == -1 ] || [  ${min_num[$count,0]} -ge  ${max_num[$count,1]} ]
				then
					echo -e "\e[31m El primer número tiene que ser mayor de 1 y el segundo no puede ser menor del primero  \e[0m \n"
					echo "		  El primer número tiene que ser mayor de 1 y el segundo no puede ser menor del primero  " >> informeRR.txt
					echo "		  El primer número tiene que ser mayor de 1 y el segundo no puede ser menor del primero  " >> informeColor.txt
				
				else
					bucle_pedir_num=1
				fi

			else
				echo -e "\e[31m El dato introducido tiene que tener el siguiente formato  (Ej: 1-20)  \e[0m \n"
				echo "		  El dato introducido tiene que tener el siguiente formato  (Ej: 1-20) " >> informeRR.txt
				echo "		  El dato introducido tiene que tener el siguiente formato  (Ej: 1-20) " >> informeColor.txt
				
			fi

		done
		
		count=$(( $count + 1 ))
	done

	

	echo "num_procesos=${min_num[0,0]}-${max_num[0,1]}" >> "$fich_random_cfg"
	echo "tiempo_llegada_procesos=${min_num[1,0]}-${max_num[1,1]}" >> "$fich_random_cfg"
	echo "rafaga_procesos=${min_num[2,0]}-${max_num[2,1]}" >> "$fich_random_cfg"
	echo "memoria_procesos=${min_num[3,0]}-${max_num[3,1]}" >> "$fich_random_cfg"

}


# Pide los rangos de la memoria del sistema 
# guarda los valores en el archivo "fich_random_cfg"
pedir_memoria_rangos() {


	local leer_dato_usuario
	local num_min_particiones
	local num_max_particiones
	local tam_min_particiones
	local tam_max_particiones

	local bucle_pedir_num_particiones
	local bucle_pedir_tam_particiones


	bucle_pedir_num_particiones=-1
	bucle_pedir_tam_particiones=-1
	num_min_particiones=-1
	num_max_particiones=-1
	tam_min_particiones=-1
	tam_max_particiones=-1

	
	#Se pide el rango de cantidad de particiones
	while  [ $bucle_pedir_num_particiones == -1 ] ;
	do
		
		read -p " Introduzca el rango de cantidad de particiones  (Ej: 1-20): " leer_dato_usuario
	
		echo "		  Introduzca el rango de cantidad de particiones  (Ej: 1-20): " >> informeRR.txt
		echo "		  Introduzca el rango de cantidad de particiones  (Ej: 1-20): " >> informeColor.txt

		echo "		    > Teclado: $leer_dato_usuario" >> informeRR.txt
		echo "		    > Teclado: $leer_dato_usuario" >> informeColor.txt

		if [[ "$leer_dato_usuario" == *"-"* ]]; 
		then

			arrIN=(${leer_dato_usuario//-/ })
			num_min_particiones=${arrIN[0]} 
			num_max_particiones=${arrIN[1]} 

			if	 [ $num_min_particiones == -1 ] || [  $num_min_particiones -ge  $num_max_particiones ]
			then
				echo -e "\e[31m El primer número tiene que ser mayor de 1 y el segundo no puede ser menor del primero  \e[0m \n"
				echo "		  El primer número tiene que ser mayor de 1 y el segundo no puede ser menor del primero" >> informeRR.txt
				echo "		  El primer número tiene que ser mayor de 1 y el segundo no puede ser menor del primero" >> informeColor.txt

			else
				bucle_pedir_num_particiones=1
			fi

		else
			echo -e "\e[31m El dato introducido tiene que tener el siguiente formato  (Ej: 1-20)  \e[0m \n"
			echo "		  El dato introducido tiene que tener el siguiente formato  (Ej: 1-20)" >> informeRR.txt
			echo "		  El dato introducido tiene que tener el siguiente formato  (Ej: 1-20)" >> informeColor.txt

		fi

	done


	#Se pide el rango de tamaño de las particiones
	while  [ $bucle_pedir_tam_particiones == -1 ] ;
	do
		
		read -p " Introduzca el rango del tamaño de dichas particiones  (Ej: 2-10): " leer_dato_usuario
		
		echo "		  Introduzca el rango del tamaño de dichas particiones  (Ej: 2-10): " >> informeRR.txt
		echo "		  Introduzca el rango del tamaño de dichas particiones  (Ej: 2-10): " >> informeColor.txt

		echo "		    > Teclado: $leer_dato_usuario" >> informeRR.txt
		echo "		    > Teclado: $leer_dato_usuario" >> informeColor.txt


		if [[ "$leer_dato_usuario" == *"-"* ]]; 
		then

			arrIN=(${leer_dato_usuario//-/ })
			tam_min_particiones=${arrIN[0]} 
			tam_max_particiones=${arrIN[1]} 

			if	 [ $tam_min_particiones == -1 ] || [  $tam_min_particiones -ge  $tam_max_particiones ]
			then
				echo -e "\e[31m El primer número tiene que ser mayor de 1 y el segundo no puede ser menor del primero  \e[0m \n"
				echo "		  El primer número tiene que ser mayor de 1 y el segundo no puede ser menor del primero" >> informeRR.txt
				echo "		  El primer número tiene que ser mayor de 1 y el segundo no puede ser menor del primero" >> informeColor.txt

			else
				bucle_pedir_tam_particiones=1
			fi

		else
			echo -e "\e[31m El dato introducido tiene que tener el siguiente formato  (Ej: 1-20)  \e[0m \n"
			echo "		  El dato introducido tiene que tener el siguiente formato  (Ej: 1-20)  " >> informeRR.txt
			echo "		  El dato introducido tiene que tener el siguiente formato  (Ej: 1-20)  " >> informeColor.txt

		fi

	done
	
	echo "num_particiones=$num_min_particiones-$num_max_particiones" >> "$fich_random_cfg"
	echo "tamanyo_particiones=$tam_min_particiones-$tam_max_particiones" >> "$fich_random_cfg"

}


# Pide los rangos de la memoria del sistema 
# guarda los valores en el archivo "fich_random_cfg"
pedir_quantum_rangos() {

	local leer_dato_usuario
	local min_quantum
	local max_quantum

	local bucle_pedir_quantum


	bucle_pedir_quantum=-1
	min_quantum=-1
	max_quantum=-1

	
	#Se pide el rango de cantidad de particiones
	while  [ $bucle_pedir_quantum == -1 ] ;
	do
		
		read -p " Introduzca el rango del quantum de ejecución  (Ej: 1-20): " leer_dato_usuario
		echo "		  Introduzca el rango del quantum de ejecución  (Ej: 1-20): " >> informeRR.txt
		echo "		  Introduzca el rango del quantum de ejecución  (Ej: 1-20): " >> informeColor.txt

		echo "		    > Teclado: $leer_dato_usuario" >> informeRR.txt
		echo "		    > Teclado: $leer_dato_usuario" >> informeColor.txt


		if [[ "$leer_dato_usuario" == *"-"* ]]; 
		then

			arrIN=(${leer_dato_usuario//-/ })
			min_quantum=${arrIN[0]} 
			max_quantum=${arrIN[1]} 

			if	 [ $min_quantum == -1 ] || [  $min_quantum -ge  $max_quantum ]
			then
				echo -e "\e[31m El primer número tiene que ser mayor de 1 y el segundo no puede ser menor del primero  \e[0m \n"
				echo "		  El primer número tiene que ser mayor de 1 y el segundo no puede ser menor del primero" >> informeRR.txt
				echo "		  El primer número tiene que ser mayor de 1 y el segundo no puede ser menor del primero" >> informeColor.txt

			else
				bucle_pedir_quantum=1
			fi

		else
			echo -e "\e[31m El dato introducido tiene que tener el siguiente formato  (Ej: 1-20)  \e[0m \n"
			echo "		  El dato introducido tiene que tener el siguiente formato  (Ej: 1-20)" >> informeRR.txt
			echo "		  El dato introducido tiene que tener el siguiente formato  (Ej: 1-20)" >> informeColor.txt

		fi

	done

	echo "tamanyo_quantum=$min_quantum-$max_quantum" >> "$fich_random_cfg"

}



mostrar_menu_opciones_algoritmo(){
	echo " Selecciona una de las dos opciones (1,2,3):"
	echo " [1] Pulsando enter"	
	echo " [2] Automatico"
	echo " [3] Complero"
}

mostrar_menu_opciones(){
	echo " Selecciona una de las dos opciones (a,b):"
	echo " [1] Introducir los datos por teclado"	
	echo " [2] Introducir los últimos datos ejecutados desde un fichero"
	echo " [3] Introducir los datos ejecutados almacenados en un fichero"
	echo " [4] Generar datos aleatorios a partir de rangos introducidos de forma manual"
	echo " [5] Introducir los últimos rangos introducidos de forma manual desde un fichero"
	echo " [6] Introducir los rangos almacenados en un fichero"
	echo " [0] Salir del programa"

	echo "		  Selecciona una de las dos opciones (a,b):" >> informeRR.txt
	echo "		  [1] Introducir los datos por teclado"	 >> informeRR.txt
	echo "		  [2] Introducir los últimos datos ejecutados desde un fichero" >> informeRR.txt
	echo "		  [3] Introducir los datos ejecutados almacenados en un fichero" >> informeRR.txt
	echo "		  [4] Generar datos aleatorios a partir de rangos introducidos de forma manual" >> informeRR.txt
	echo "		  [5] Introducir los últimos rangos introducidos de forma manual desde un fichero" >> informeRR.txt
	echo "		  [6] Introducir los rangos almacenados en un fichero" >> informeRR.txt
	echo "		  [0] Salir del programa" >> informeRR.txt

	echo "		  Selecciona una de las dos opciones (a,b):" >> informeColor.txt
	echo "		  [1] Introducir los datos por teclado"	 >> informeColor.txt
	echo "		  [2] Introducir los últimos datos ejecutados desde un fichero" >> informeColor.txt
	echo "		  [3] Introducir los datos ejecutados almacenados en un fichero" >> informeColor.txt
	echo "		  [4] Generar datos aleatorios a partir de rangos introducidos de forma manual" >> informeColor.txt
	echo "		  [5] Introducir los últimos rangos introducidos de forma manual desde un fichero" >> informeColor.txt
	echo "		  [6] Introducir los rangos almacenados en un fichero" >> informeColor.txt
	echo "		  [0] Salir del programa" >> informeColor.txt

}

# Funcion  que pide el ajuste del programa
pedir_ajuste(){
	local ajuste_num

	ajuste_num=-1
	echo " Selecciona algoritmo de ubicación de memoria"
	echo " [0] Primer ajuste"
	echo " [1] Mejor ajuste"
	echo " [2] Peor ajuste"

	echo "	  Selecciona algoritmo de ubicación de memoria" >> informeRR.txt
	echo "	  [0] Primer ajuste" >> informeRR.txt
	echo "	  [1] Mejor ajuste" >> informeRR.txt
	echo "	  [2] Peor ajuste" >> informeRR.txt

	echo "	  Selecciona algoritmo de ubicación de memoria" >> informeColor.txt
	echo "	  [0] Primer ajuste" >> informeColor.txt
	echo "	  [1] Mejor ajuste" >> informeColor.txt
	echo "	  [2] Peor ajuste" >> informeColor.txt

	
	read -p " Tu elección->" ajuste_num

	echo "	  Teclado: $ajuste_num" >> informeRR.txt
	echo "	  Teclado: $ajuste_num" >> informeColor.txt

	while (( ajuste_num < 0 || ajuste_num > 2 ));
	do
		echo " Entrada no válida, sólo 0, 1 y 2 admitido"
		echo " Selecciona algoritmo de ubicación de memoria"
		echo " [0] Primer ajuste"
		echo " [1] Mejor ajuste"
		echo " [2] Peor ajuste"

		echo "	  Entrada no válida, sólo 0, 1 y 2 admitido" >> informeRR.txt
		echo "	  Selecciona algoritmo de ubicación de memoria" >> informeRR.txt
		echo "	  [0] Primer ajuste" >> informeRR.txt
		echo "	  [1] Mejor ajuste" >> informeRR.txt
		echo "	  [2] Peor ajuste" >> informeRR.txt

		echo "	  Entrada no válida, sólo 0, 1 y 2 admitido" >> informeColor.txt
		echo "	  Selecciona algoritmo de ubicación de memoria" >> informeColor.txt
		echo "	  [0] Primer ajuste" >> informeColor.txt
		echo "	  [1] Mejor ajuste" >> informeColor.txt
		echo "	  [2] Peor ajuste" >> informeColor.txt

		read -p " Tu elección->" ajuste_num
		echo "	  Teclado: $ajuste_num" >> informeRR.txt
		echo "	  Teclado: $ajuste_num" >> informeColor.txt

	done
	if [ $ajuste_num == 0 ];then
		gl_ajuste="fa"
		echo "		> Primer ajuste" >> informeRR.txt
		echo "		> Primer ajuste" >> informeColor.txt
	fi
	if [ $ajuste_num == 1 ];then
		gl_ajuste="ba"
		echo "		> Mejor ajuste" >> informeRR.txt
		echo "		> Mejor ajuste" >> informeColor.txt
		
	fi
	if [ $ajuste_num == 2 ];then
		gl_ajuste="wa"
		echo "		> Peor ajuste" >> informeRR.txt
		echo "		> Peor ajuste" >> informeColor.txt
	fi
	if [ $debug -eq 1 ];then
		read -p "Ajuste seleccionado es ${gl_ajuste}"
	fi
}


# Opcion 1: es la opcion de rellenar los datos a mano
menu_opcion_1() {
	pedir_memoria
	# Lectura del quantum.
	read -p " Introduce el quantum de ejecución:" quantum

	while ! mayor_cero $quantum
	do
		clear
		imprime_cabecera
		echo " Entrada no válida"
		read -p " Introduce el quantum de ejecución:" quantum
	done
	echo "		>> Quantum de tiempo: $quantum" >> informeRR.txt
	echo "		>> Quantum de tiempo: $quantum" >> informeColor.txt
	# Leemos los datos concretos de los procesos.
	proc_new="s"
	num_proc=`expr 0`
	lectura_datprocesos
	ordenacion_procesos
}

# Opcion 2: es la opcion de rellenar los datos desde el ultimo fichero
menu_opcion_2() {
	clear
	imprime_cabecera

	if [ $opcion == "a" ]; 
	then #RR
		if [ -f 'ultimosRR.rr' ]
		then # En el caso de que el fichero exista tambien hay que compobar que esta vacio

			if [ -s 'ultimosRR.rr' ]
			then # El archivo si que tiene contenido

				
				fich="ultimosRR.rr"
				lectura_fichero # Leemos los datos del fichero

			else # El alchivo esta vacio

				echo -e "\e[31m  El archivo ('ultimosRR.rr') no tiene contenido  \e[0m \n"
				lee_datos_menu

			fi

		else # En el caso de no existir fichero mostramos el error por consola

			echo -e "\e[31m  No existe fichero de ultima ejecución ('ultimosRR.rr') \e[0m \n"
			lee_datos_menu

		fi
	else #RRV
		if [ -f 'ultimosRR.rrv' ]
		then # En el caso de que el fichero exista tambien hay que compobar que esta vacio

			if [ -s 'ultimosRR.rrv' ]
			then # El archivo si que tiene contenido

				
					fich="ultimosRR.rrv"
					
				lectura_fichero # Leemos los datos del fichero

			else # El alchivo esta vacio

				echo -e "\e[31m  El archivo ('ultimosRR.rrv') no tiene contenido  \e[0m \n"
				lee_datos_menu

			fi

		else # En el caso de no existir fichero mostramos el error por consola

			echo -e "\e[31m  No existe fichero de ultima ejecución ('ultimosRR.rrv') \e[0m \n"
			lee_datos_menu

		fi
	fi



}

# Opcion 3: es la opcion de rellenar los datos de un fichero que el usuario seleccione
menu_opcion_3() {
	clear
	imprime_cabecera
	if [ $opcion = "a" ] #RR
	then
		ls | grep .rr$ > listado.temp
	else # RRV
		ls | grep .rrv$ > listado.temp
	fi
	# Muestra listados con ficheros
	echo -e " Ficheros de datos que he encontrado en el directorio `pwd`: \n"
	echo "		  Ficheros de datos que he encontrado en el directorio `pwd`:" >> informeRR.txt
	echo "		  Ficheros de datos que he encontrado en el directorio `pwd`:" >> informeColor.txt
	cat listado.temp
	echo -e "\n"
	if [ $debug -eq 1 ]; then
		if [ $opcion == "a" ]; then #RR
			fich="${fich_modo_debug}.rr"
		else #RRV
			fich="${fich_modo_debug}.rrv"
		fi
	else
		read -p " Introduce uno de los ficheros del listado:" fich
		echo "		  Teclado: $fich" >> informeRR.txt
		echo "		  Teclado: $fich" >> informeColor.txt
	fi
	while [ ! -f $fich ] # Si el fichero no existe, lectura erronea
	do
		clear
		imprime_cabecera
		cat listado.temp
		read -p " Entrada no válida, vuelve a intentarlo. Introduce uno de los ficheros del listado:" fich
		echo "		  Entrada no válida, vuelve a intentarlo. Introduce uno de los ficheros del listado:" >> informeRR.txt
		echo "		  Entrada no válida, vuelve a intentarlo. Introduce uno de los ficheros del listado:" >> informeColor.txt
	done
	lectura_fichero # Leemos los datos del fichero
	rm -r listado.temp # Borra el temporal
}

# Opcion 4: es la opcion de crear el arhcivo cfg que va a tener los rangos para generar aleatoriamente
menu_opcion_4() {

	# Creamos el fichero
	#echo "ajuste=$gl_ajuste-$gl_ajuste" > "$fich_random_cfg"

	clear
	imprime_cabecera
	pedir_memoria_rangos
	pedir_quantum_rangos
	pedir_procesos_rangos

	lectura_fichero_config "ultimaRandomRR.cfg"

}

# Opcion 5: es la opcion de rellenar los datos desde el ultimo fichero de rangos
menu_opcion_5() {

	clear
	imprime_cabecera

	if [ -f 'ultimaRandomRR.cfg' ]
	then # En el caso de que el fichero exista tambien hay que compobar que esta vacio

		if [ -s 'ultimaRandomRR.cfg' ]
		then # El archivo si que tiene contenido

				
			lectura_fichero_config "ultimaRandomRR.cfg" # Leemos los datos del fichero

		else # El alchivo esta vacio

			echo -e "\e[31m  El archivo ('ultimaRandomRR.cfg') no tiene contenido  \e[0m \n"
			#lee_datos_menu

		fi

	else # En el caso de no existir fichero mostramos el error por consola

		echo -e "\e[31m  No existe fichero de ultima ejecución ('ultimaRandomRR.cfg') \e[0m \n"
		#lee_datos_menu

	fi
}

# Opcion 6: es la opcion de rellenar los datos desde un fichero de rangos seleccionado
menu_opcion_6() {

	clear
	imprime_cabecera
	if [ $opcion = "a" ] #RR
	then
		ls | grep .cfg$ > listado.temp
	else # RRV
		ls | grep .cfg$ > listado.temp
	fi
	# Muestra listados con ficheros
	echo -e " Ficheros de datos que he encontrado en el directorio `pwd`: \n"
	echo "		  Ficheros de datos que he encontrado en el directorio `pwd`:" >> informeRR.txt
	echo "		  Ficheros de datos que he encontrado en el directorio `pwd`:" >> informeColor.txt
	cat listado.temp
	echo -e "\n"
	if [ $debug -eq 1 ]; then
		if [ $opcion == "a" ]; then #RR
			fich="${fich_modo_debug}.cfg"
		else #RRV
			fich="${fich_modo_debug}.cfg"
		fi
	else
		read -p " Introduce uno de los ficheros del listado:" fich
		echo "		  Teclado: $fich" >> informeRR.txt
		echo "		  Teclado: $fich" >> informeColor.txt
	fi
	while [ ! -f $fich ] # Si el fichero no existe, lectura erronea
	do
		clear
		imprime_cabecera
		cat listado.temp
		read -p " Entrada no válida, vuelve a intentarlo. Introduce uno de los ficheros del listado:" fich
		echo "		  Entrada no válida, vuelve a intentarlo. Introduce uno de los ficheros del listado:" >> informeRR.txt
		echo "		  Entrada no válida, vuelve a intentarlo. Introduce uno de los ficheros del listado:" >> informeColor.txt
	done
	
	lectura_fichero_config "$fich"

	rm -r listado.temp # Borra el temporal

}

# Lectura de los datos (quantum y nro procesos/fichero) y diseño de informe.
lee_datos_menu() {

	# Lectura de fichero
	mostrar_menu_opciones
	read -p " Selecciona una de las siguientes opciones:" dat_fich
	
	echo "		  Teclado: $dat_fich" >> informeRR.txt
	echo "		  Teclado: $dat_fich" >> informeColor.txt
	# COMPROBACIÓN DE LECTURA
	if [ -z $dat_fich ] # Si la lectura está vacía, valor por defecto n
		then
		dat_fich="1"
	fi
	((rep++))
	
	  
	# Comporbamos que el numero no esta ente 0 y 6, el numero no esta entre el rango del menu
	while [ $dat_fich -ge 7 ] || [ $dat_fich -le -1 ]  # Lectura erronea
	do
		clear
		imprime_cabecera
		echo " Entrada no válida"
		echo "		  Entrada no válida" >> informeRR.txt
		echo "		  Entrada no válida" >> informeColor.txt
		mostrar_menu_opciones
		read -p " Selecciona una de las siguientes opciones:" dat_fich
		echo "		  Teclado: $dat_fich" >> informeRR.txt
		echo "		  Teclado: $dat_fich" >> informeColor.txt
			if [ -z $dat_fich ]
			then
				dat_fich="1"
			fi
	done

	#
	# Opciones del menu anidadas en if else
	#


	
	if [ $dat_fich = "0" ] # Opciones 0: Salir del programa
	then
		echo " Saliendo..."			
		echo "		    >  Saliendo..." >> informeRR.txt
		echo "		    >  Saliendo..." >> informeColor.txt

		exit 1
	else

		if [ $dat_fich = "1" ] # Opciones 1: INTRODUCIR LOS DATOS POR TECLADO
		then
			echo "		    >  [1] Introducir los datos por teclado" >> informeRR.txt
			echo "		    >  [1] Introducir los datos por teclado" >> informeColor.txt

			menu_opcion_1

		else 
		
			if [ $dat_fich = "2" ] # Opciones 2: INTRODUCIR LOS DATOS DESDE EL ULTIMO FICHERO
			then

				echo "		    >  [2] Introducir los últimos datos ejecutados desde un fichero" >> informeRR.txt
				echo "		    >  [2] Introducir los últimos datos ejecutados desde un fichero" >> informeColor.txt
				menu_opcion_2

			else
				if [ $dat_fich = "3" ] # Opciones 3: INTRODUCIR LOS DATOS DESDE UN FICHERO
				then
					echo "		    >  [3] Introducir los datos ejecutados almacenados en un fichero" >> informeRR.txt
					echo "		    >  [3] Introducir los datos ejecutados almacenados en un fichero" >> informeColor.txt

					menu_opcion_3

				else
					if [ $dat_fich = "4" ] # Opciones 4: GENERAR DATOS ALEATORIAMENTE EN UN RANGO
					then
						echo "		    >  [4] Generar datos aleatorios a partir de rangos introducidos de forma manual" >> informeRR.txt
						echo "		    >  [4] Generar datos aleatorios a partir de rangos introducidos de forma manual" >> informeColor.txt

						menu_opcion_4

					else
						if [ $dat_fich = "5" ] # Opciones 5: INTRODUCIR LOS RANGOS DESDE EL ULTIMO FICHERO
						then

							echo "		    >  [5] Introducir los últimos rangos introducidos de forma manual desde un fichero" >> informeRR.txt
							echo "		    >  [5] Introducir los últimos rangos introducidos de forma manual desde un fichero" >> informeColor.txt

							menu_opcion_5

						else # Opciones 6: INTRODUCIR LOS RANGOS DESDE UN FICHERO
							echo "		    >  [6] Introducir los rangos almacenados en un fichero" >> informeRR.txt
							echo "		    >  [6] Introducir los rangos almacenados en un fichero" >> informeColor.txt

							menu_opcion_6

						fi
					fi
				fi
			fi
		fi
	fi


}

# Reestructuración de la cola auxiliar cuando sale el primer elemento
reestructura_aux(){

	# Tiempo restante para labores de E/S del resto de procesos de la cola
	tiempo_restante=`expr $tiempo_transcurrido - ${FIN_ES[0]}`

	# Si había mas de un proceso en la cola auxiliar, se reestructura:
	procesos_enaux=`expr $procesos_colaauxiliar - 1`
	indice=`expr 0`
	if [ $procesos_enaux -ne '0' ]
		then
		while [ $indice -lt $procesos_enaux ]
		do
			sig=`expr $indice + 1`
			if [ $tiempo_restante -lt ${FIN_ES[$sig]} ]
				then
				FIN_ES[$sig]=`expr ${FIN_ES[$sig]}`
			else
				tiempo_restante=`expr $tiempo_restante - ${FIN_ES[$sig]}`
				FIN_ES[$sig]=`expr 0`
			fi
			AUX[$indice]=${AUX[$sig]}
			FIN_ES[$indice]=${FIN_ES[$sig]}
			indice=`expr $indice + 1`
		done
	fi
	# Al sacar un proceso de la cola FIFO, borramos la ultima entrada y decrementamos un proceso en cola.
	unset -v AUX[$indice]
	unset -v FIN_ES[$indice]
	procesos_colaauxiliar=`expr $procesos_colaauxiliar - 1`

}


#aumenta el recorrido para que coja mas procesos cuando un proceso acaba y deja una particion libre
aumentar_recorrido(){
	if [ $proc_exec -lt $num_proc ]
	then
		proc_exec=`expr $proc_exec + 1`
		cerr=`expr 0`
	fi

}

tiempo_llegadaOK() {

	if [ ${T_ENTRADA[0]} -gt '0' ]
	then
		EN_ESPERA[0]="No"	
	fi
}

#crea el fichero con los datos de la ejecución (ultimosRR)
meterAfichero() {
	finSN=`expr $num_proc - 1`
	#imprime particiones
	for valorpart in ${PART_SIZE[*]};do
		echo -n "$valorpart " >> ultimosRR.txt
	done
	#imprime el quantum
	echo -e "\n$quantum"  >> ultimosRR.txt
	for(( or=0; or < $num_proc ; or++ ))
	do
		#imprime los procesos
		echo -n "${T_ENTRADA_I[$or]} " >> ultimosRR.txt
		if [ $opcion  == "a" ]; then #RR
			echo -n "${PROCESOS_I[$or]} " >> ultimosRR.txt
			echo  "${MEMORIA_I[$or]}" >> ultimosRR.txt

		else #RRV
			echo -n "${MEMORIA_I[$or]} " >> ultimosRR.txt
			echo -n "${PROCESOS_I[$or]}" >> ultimosRR.txt
			echo -n "${ENTRADA_SALIDA[$or]} " >> ultimosRR.txt
			echo -n "${MOMENTO[$or]} " >> ultimosRR.txt
			echo "${DURACION[$or]} " >> ultimosRR.txt

		fi
	done
	echo "" >> ultimosRR.txt
}

# USED IN ALGORYTHM
comprueba_espacio_libre() { # comprobamos que los procesos puedan entrar en memoria en algun momento, si fueran mayores que las particiones, cambiamos su estado a sin memoria
					
	local i
					
	for((i=0;i<$num_proc;i++));do # recorremos todos los procesos
	
		cuento=0
		for numpar in ${!PART_SIZE[*]};do #recorremos las particiones
		
			if [ ${MEMORIA[$i]} -gt ${PART_SIZE[$numpar]} ];then
			
				((cuento++)) # el proceso es mayor que la particion, sumamos 1 al contador
				
			fi
		
		done
		if [ $cuento -eq ${#PART_SIZE[*]} ];then #si el contador = al nº particiones, significa que no podrá entrar en ningun momento a las particiones.
		
			ch_estado $i 7 "compr_esp_libre"
		
		fi
	
	done
}

cargar_en_memoria() { #se le pasa un argumento que es el proc actual

					if [[ -z ${vuelta[$1]} ]];then #comprobacion de solo 1 vez entra en memoria, si el elemento del array correspondiente al proceso actual esta vacío, lo pone a 0 
							vuelta[$1]=`expr 0`
					fi

					if [[ ${vuelta[$1]} -eq 0 ]] 
							then
						# 20170912EN_MEMO[$1]="Si"
						proc_memoria=`expr $proc_memoria + 1`
						echo -e "\e[0;34mCARGA>>\e[0m en memoria el PROCESO `expr $1 + 1`  y OCUPA ${MEMORIA[$1]} espacios de memoria en la PARTICIÓN ${PART[$1]}" >> log.temp
						num_part=`expr ${PART[$1]}`						
						PART_SIZE[$num_part]=`expr ${PART_SIZE[num_part]} - ${MEMORIA[$1]}`	
						vuelta[$1]=`expr 1`
					fi
}


llenar_buffer() {
					
						for ((px=0;px<$num_proc;px++));do
								
								if [[ "${ESTADO[$px]}" == "En Espera" ]];then
								
										buscar_particion $px
										if [[ $tam_par -gt 0 ]];then
												
												cargar_en_memoria $px
												ch_estado $px 6 "llenar_buffer"
									
										fi
								fi	
						done

}

# Teniendo en cuenta el estado actual de un quantum, modifica las variables globales gl_medio_quantum y gl_quantum_restante asumiendo que se ha consumido X instantes de golpe segun indica la vriable global gl_resta_quantum
# Arg1: consumo instantes, significa que asumira que acaba de consumirse un instante estipulado en la forma de restar unidades
actualiza_quantum_tiempos() {
	local consumo_instantes=$1
	local resta_unidades
	local backup_tiempo=$gl_quantum_restante
	if [[ $gl_resta_por_quantum == 0 ]];then
		resta_unidades=$gl_tiempo_restar
	else
		resta_unidades=$quantum
	fi
	if [[ $consumo_instantes == 1 ]];then
		(( gl_quantum_restante-=resta_unidades ))
	fi
	if [[ $gl_quantum_restante -lt 0 ]];then #Si ha consumido todo su tiempo, lo refresecamos asumiendo que comenzaría una vez de nuevo un nuevo quantum
		gl_quantum_restante=$quantum
	fi
	#gl_medio_quantum=$((tiempo_transcurrido % quantum))
	gl_medio_quantum=0
	if [[ $gl_quantum_restante -gt 0 && $gl_quantum_restante -lt $quantum ]];then # Si el quantum restante está entre 0 y el quantum en sí (no incluidos)
		gl_medio_quantum=1
	fi
	if [[ $gl_debug == 1 ]];then
		echo -e "\t(act_quant_tiemp): ........................Se pasa de ${backup_tiempo} a ${gl_quantum_restante} debudo a un instante consumido de ${resta_unidades} unidades (gl_medio_quantum esta a ${gl_medio_quantum})------------------"
	fi
}

# busca la primera particion libre y devuelve el indice, en la variable global $libre -1 si no hay ninguna libre
buscar_part_libre() {
	local pa
	local pr
	libre=-1
	for((pa=0 ; pa < $n_par ; pa++ ))
	do
		for((pr=0 ; pr < $n_par ; pr++ ))
		do
			if [ ${PART[$pr]} -eq -1 ];then
				libre=$pa
				break
			fi
		done
		if [[ $libre != -1 ]];then
			break
		fi
	done
	if [ $debug -eq 1 ];then	
		echo -e "\tbuscar_part_libre: Hallada particion libre ${libre}"
		read -p "toca intro"
	fi
}
#busca el primer proceso que se puede asignar a memoria y modifica la var global gl_primero a -1 si no lo hay o >=0 con el indice de proceso
buscar_primer_proceso_a_asignar() { 
	local tiem
	local i
	gl_primero=-1
	i=0
	for tiem in "${TIEMPO[@]}"
	do
		echo "TIEMPO[$i]=${tiem}, PART[$i]=${PART[$i]}"

		if [[ $tiem -gt 0 && ${PART[$i]} == -1 ]];then
			if [[ $gl_debug == 1 ]];then
				echo "bus_pri_proc_a_asig: DETECTADO 1 en posicion indice ${i}!!!!"
			fi
			gl_primero=$i
			break
		fi
		((i++))
	done
}

#busca el primer proceso que ya esta asignado memoria y modifica la var global gl_asignado a -1 si no lo hay o >=0 con el indice de proceso
buscar_primer_proceso_asignado() { 
	local pa
	local i
	gl_asignado=-1
	i=0
	for pa in "${PART[@]}"
	do
		if [[ $pa -gt -1 ]];then
			if [[ $gl_debug == 1 ]];then
				echo "bus_pri_proc_asig: DETECTADO 2 (primer proceso de la lista que esta asignado en memoria es indice ${i})!!!!"
			fi
			gl_asignado=$i
			break
		fi
		((i++))
	done

}
# Modifica la variable global ind_part_ocupada con el indice del proceso que está ocupando el indice de memoria que se le pasa por parametro (-1 si no la hay)
buscar_indice_memoria() {
	local i
	local part_search
	part_search=`expr $1`
	ind_part_ocupada=-1
	
	for((i=0 ; i < $num_proc ; i++ )) # 1 -1 -1 -1 -1 -1 -1 PART[..]
	do
		if [[ ${PART[$i]} == $part_search ]];then
			ind_part_ocupada=$i
			break
		fi
	done
}

# Compburea si existe algun proceso en ejecucion y modifica la variable global gl_uno_en_ejecucion
uno_en_ejecucion() {
	local pr
	gl_uno_en_ejecucion=0
	for((pr=0 ; pr < $num_proc ; pr++ ))
	do
		if [[ ${ESTADO[$pr]} == "En Ejecucion" ]];then
			
			gl_uno_en_ejecucion=1
			break
		fi
	done
}

# Compburea si existe algun proceso en ejecucion y modifica la variable global gl_primero_en_ejecucion
primero_en_ejecucion() {
	local pr
	gl_primero_en_ejecucion=-1 # Asuncion de que no hay ninguno
	for((pr=0 ; pr < $num_proc ; pr++ ))
	do
		if [[ ${ESTADO[$pr]} == "En Ejecucion" ]];then
			
			gl_primero_en_ejecucion=$pr
			break
		fi
	done
}

# Compburea si existe algun proceso en ejecucion y modifica la variable global gl_quedan_procesos_anteriores
quedan_procesos_anteriores() {
	local pr
	gl_quedan_procesos_anteriores=0
	if [[ $proc_rr -gt -1 ]];then
	for((pr=0 ; pr < $proc_min_rr ; pr++ ))
	do
		if [[ ${TIEMPO[$pr]} -gt 0 ]];then
			
			gl_quedan_procesos_anteriores=1
			break
		fi
	done
	fi
}

# Comprueba si una particion de memoria ya esta siendo asignada y modifica la variable global asingada como valor por retorno
part_mem_ocupada() {

	local pr
	local part_analizar=$1
	local espacio_libre
	local total_memoria
	
	buscar_indice_memoria $part_analizar
	
	espacio_libre=`expr ${TAM_PART[$part_analizar]} - ${MEMORIA[$ind_part_ocupada]}`

	total_memoria=${TAM_PART[$part_analizar]}
	asignada=0

	for((pr=0 ; pr < $num_proc ; pr++ ))
	do
		if [ ${PART[$pr]} -eq $1 ];then
			
			asignada=1
			break
		fi
	done
}


buscar_particion_primer_ajuste() { # comprobamos si el proceso se puede meter en memoria
	# arg1: Numero de proceso ($1)
	local pa # variable local para particiones de memoria
	local pr # variable local para procesos actuales
	local num_asignadas=0
	local proceso_actual # variable local para procesos que pueden ser analizados para ocupar memoria
	local i
	local PROCESOS_DISPONIBLES_TIEMPO
	local primera_vez
	local encontrada_part
	primera_vez=1
	encontrada_part=0

	# Iteracion de liberacion, si todas las partciones estan ocupadas, no es necesario seguir buscando
	for((pa=0 ; pa < $n_par ; pa++ ))
	do
		part_mem_ocupada $pa
		if [[ $asignada == 1 ]];then
			(( num_asignadas++ ))
		fi
		
	done
	
	if [[ $num_asignadas -ge $n_par ]];then
		if [[ $debug == 1 ]];then
			echo "buscar_part_fa: Saliendo, todas las particiones estan ocupadas"
		fi
		return
	fi

	alguno_en_memoria # Comprueba y modifica la variable global gl_en_memoria
	gl_nueva_reasignacion=0
	gl_nueva_asignacion=0
	if [[ $gl_en_memoria == 0 ]];then
		gl_nueva_reasignacion=1
	fi

	proceso_actual=`expr $1`
	for((pr=0; pr < $num_proc; pr++ ))
	do
		if [ ${T_ENTRADA[$pr]} -le $tiempo_transcurrido ];then
			
			if [[ ${PART[$pr]} == -1 && ${ESTADO[$pr]} != "Finalizado" && ${ESTADO[$pr]} != "En Memoria" ]];then
				PROCESOS_DISPONIBLES_TIEMPO[$i]=`expr $pr`
				((i++))	
			fi
		fi
	done

	if [ $debug -eq 1 ];then
		echo "####################### proc disponibles #######################"
	fi
	for proceso_disponible in "${PROCESOS_DISPONIBLES_TIEMPO[@]}"
	do
		if [ $debug -eq 1 ];then
			echo -e "\tproc_disponible=$proceso_disponible"
		fi
	done
	if [ $debug -eq 1 ];then
		echo "####################### END proc disponibles #######################"
	fi

	proceso_disponible=`expr $1`
	i=0
	proc_elegido=-1
	
	for proceso_disponible in "${PROCESOS_DISPONIBLES_TIEMPO[@]}"
	do
		proceso_actual=`expr $proceso_disponible`
		
		if [ $debug -eq 1 ];then
			echo "Estamos analizando proceso $proceso_actual"
		
			echo -e "\tbuscar_part_fa: Estamos analizando el proceso plausible $proceso_dipsonible"
			echo -e "\tbuscar_part_fa: Entrada con proceso indice ${1} Su memoria es ${MEMORIA[$proceso_actual]}tiene la particion ${PART[$proceso_actual]})"
		fi
		if [ ${PART[$proceso_actual]} -gt -1 ];then # el proceso a analizar ya esta siendo ocupado por una particion
			# no hacer nada
			if [ $debug -eq 1 ];then	
				echo -e "\tbuscar_part_fa: Ya estaba asignada particion, no hacer nada"
			fi

		else

			encontrada_part=0
			for((pa=0 ; pa < $n_par ; pa++ ))
			do
				if [ $debug -eq 1 ];then	
					echo -e "\tbuscar_part_fa: Estamos en el proceso indice ${1}. Particion $pa (Su tamano libre es de ${PART_SIZE[$pa]} y su total es de ${TAM_PART[$pa]}). El proceso ocupa una memoria de ${MEMORIA[$proceso_actual]}. Este proceso esta en estado ${ESTADO[$proceso_actual]} en la particion ${PART[$proceso_actual]}):"
				fi
				if [[ ${PART[$pa]} -gt -1 ]];then
					ninguno_en_memoria=0
				fi

				if [ $debug -eq 1 ];then
					echo -e "\tbusc_part_fa:MEMORIA[$proceso_actual]=${MEMORIA[$proceso_actual]}, TAM_PART[$pa]=${TAM_PART[$pa]}"
				fi
				
				if [[ ${ESTADO[$proceso_actual]} == Finalizado ]];then # l proceso ya está acabado, lo ignoramos

					break

				elif [ ${MEMORIA[$proceso_actual]} -le ${TAM_PART[$pa]} ];then #El proceso indice $proceso_actual cabe en esta particion $pa
					if [ $debug -eq 1 ];then
						echo -e "\tbuscar_part_fa: Candidata a ser particion ok"
					fi
		
					part_mem_ocupada $pa
				
					if [ $asignada -eq 0 ];then # Solo asigna en el caso que este libre la particion al proceso
						if [[ $debug == 1 || $debug2 == 1 ]];then
							echo "fa: Es primera vez? $primera_vez"
						fi
						if [ $primera_vez -eq 1 ];then
							
							primera_vez=0
							encontrada_part=1
						fi
						
						if [[ $proc_elegido == -1 ]];then
							proc_elegido=$proceso_actual
						fi

						if [ $debug -eq 1 ];then	
							echo -e "\tbuscar_part_fa: OK! Asignamos la particion $pa al proceso $proceso_actual!!!"
						fi

						PART[$proceso_actual]=`expr $pa`
						EN_MEMO[$proceso_actual]="Si"
						ch_estado $proceso_actual 2 "busc_pa_fa"
						encontrada_part=1
						gl_nueva_asignacion=1
						((i++))
						break
					fi
					
				else # El proceso no esta ni acabado y tampoco cabe en memoria

					((i++))
				fi
				
			done
			if [ $encontrada_part -eq 0 ];then
				if [ $debug -eq 1 ];then
					echo "busar_part_fa: Imposible hallar una particion para el proceso a analizar indice $proceso_actual. Nos largamos"
				fi
				break
			fi
		fi
	done
	
	if [ $debug -eq 1 ];then
		echo  -e "\tproc_elegido=$proc_elegido"
	fi
	if [ $debug -eq 1 ];then
		pausaConIteraciones "buscar_part_fa: Saliendoo....."
	fi
}

buscar_particion_mejor_ajuste() { # comprobamos si el proceso se puede meter en memoria
	# arg1: Numero de proceso ($1)
	local pa # variable local para particiones de memoria
	local pr # variable local para proceso actual
	local num_asignadas=0
	local proceso_actual # variable local para procesos que pueden ser analizados para ocupar memoria
	local min_asumido
	local min_asumido_check
	local pa_found # Es global
	local pr # variable local para procesos actuales
	local proceso_actual # variable local para procesos que pueden ser analizados para ocupar memoria
	local i
	local PROCESOS_DISPONIBLES_TIEMPO
	local primera_vez
	local encontrada_part
	primera_vez=1
	encontrada_part=0

	alguno_en_memoria # Comprueba y modifica la variable global gl_en_memoria
	gl_nueva_reasignacion=0
	gl_nueva_asignacion=0
	if [[ $gl_en_memoria == 0 ]];then
		gl_nueva_reasignacion=1
	fi

	# Iteracion de liberacion, si todas las partciones estan ocupadas, no es necesario seguir buscando
	for((pa=0 ; pa < $n_par ; pa++ ))
	do
		part_mem_ocupada $pa
		if [[ $asignada == 1 ]];then
			(( num_asignadas++ ))
		fi
	done
	if [[ $num_asignadas -ge $n_par ]];then
		if [[ $debug == 1 ]];then
			echo "buscar_part_ba: Saliendo, todas las particiones estan ocupadas"
		fi
		return
	fi

	proceso_actual=`expr $1`
	i=0
	for((pr=0; pr < $num_proc; pr++ ))
	do
		if [ ${T_ENTRADA[$pr]} -le $tiempo_transcurrido ];then
			
			if [[ ${PART[$pr]} == -1 && ${ESTADO[$pr]} != "Finalizado" && ${ESTADO[$pr]} != "En Memoria" ]];then
				PROCESOS_DISPONIBLES_TIEMPO[$i]=`expr $pr`
				((i++))
				
			fi
		fi
	done

	if [ $debug -eq 1 ];then
		echo "####################### proc disponibles #######################"
	
		for proceso_disponible in "${PROCESOS_DISPONIBLES_TIEMPO[@]}"
		do
		
			echo -e "\tproc_disponible=$proceso_disponible"
		
		done
	
		echo "####################### END proc disponibles #######################"
	fi
	
	proceso_disponible=`expr $1`
	i=0
	proc_elegido=-1
	buscar_primer_proceso_asignado # modifica la variable global gl_asignado con indice del primer proceso que este asignado a auna particion, -1 si no hubiera ninguno
	if [ $debug -eq 1 ];then	
		echo -e "\tbuscar_part_ba: buscar_primer_proceso_asignado()=$gl_asignado (-1=ninguno)"
	fi

	# Bucle para calcular el proceso que tiene el peor ajuste, es decir al que le sobre mas memoria libre en caso de estar asignado
	for proceso_disponible in "${PROCESOS_DISPONIBLES_TIEMPO[@]}"
	do
		proceso_actual=`expr $proceso_disponible`
		#TODO: Se debería detectar el caso final, que seria el caso en que los ultimo procesos de la lista tengan asignada memoria y ya no haga falta hacer mas asignaciones

		#if [[ $gl_asignado -gt -1 && $proceso_actual -ge `expr $gl_asignado + $n_par` ]];then # Si hay algun proceso asignado
			if [ $debug -eq 1 ];then	
				echo -e "\tbuscar_part_ba: FAKE saliendo, no podemos asignar más procesos ya que gl_asignado=${gl_asignado}, proc_disp=$proceso_disponible"
			fi

		
		if [ $debug -eq 1 ];then
			echo "Estamos analizando proceso $proceso_actual"
			echo -e "\tbuscar_part_ba: Estamos analizando el proceso plausible $proceso_disponible"
			echo -e "\tbuscar_part_ba: Su tamano es ${MEMORIA[$proceso_actual]}, tiene la particion ${PART[$proceso_actual]}"
		fi
		if [ ${PART[$proceso_actual]} -gt -1 ];then # el proceso a analizar ya esta siendo ocupado por una particion
			# no hacer nada
			if [ $debug -eq 1 ];then	
				echo -e "\tbuscar_part_ba: Ya estaba asignada particion, no hacer nada"
			fi
			continue
		fi
		
		min_asumido=-1 # Codigo por defecto de no encontrado
		pa_found=-1
		# busca el primer candidato valido aunque no sea el mejor, osea el primero que quepa en la primera part libre de memoria
		for((pa=0 ; pa < $n_par ; pa++ ))
		do
			part_mem_ocupada $pa
			if [ $debug -eq 1 ];then	
				echo -e "\tbuscar_part_ba: part_mem_ocupada($pa)=$asignada (0 o 1)"
			fi
			if [ $asignada -eq 1 ];then # Ya estaba asignada, esta no vale
				if [ $debug -eq 1 ];then	
					echo -e "\tbuscar_part_ba: Esta particion se ignora, ya estaba ocupada"
				fi
			
			else
				
				(( min_asumido = TAM_PART[$pa] - MEMORIA[$proceso_actual] ))
				if [ $debug -eq 1 ];then	
					echo -e "\tbuscar_part_ba: Min asumido calculado es ${min_asumido}"
				fi
				if [ $min_asumido -lt 0 ];then
					if [ $debug -eq 1 ];then	
						echo -e "\tbuscar_part_ba: Particion indice $pa no cabe en el proceso indice $proceso_actual"
					fi
					min_asumido=-1
				else
					if [ $debug -eq 1 ];then	
						echo -e "\tbuscar_part_ba: Particion indice $pa es candidata para el proceso indice $proceso_actual"
					fi
					pa_found=$pa
					break
				fi
			fi
		done
		
		if [[ $min_asumido == -1 ]];then
			if [ $debug -eq 1 ];then
				echo -e "\tbuscar_part_ba: SALIENDO POR PROCESO INCABIBLE. No existe ninguna particion libre o que quepa. No hace falta buscar mas"
			fi
			break
		else
			if [ $debug -eq 1 ];then
				echo -e "\tbuscar_part_ba: Hemos hallado un candidato de min_asumido=${min_asumido} en la particion ${pa_found}"
			fi
			min_asumido_check=$min_asumido
			# Calcula el que menos espacio desperdicia de todas las particiones disponibles
			for((pa=0 ; pa < $n_par ; pa++ ))
			do
				part_mem_ocupada $pa
				if [ $debug -eq 1 ];then
					echo -e "\tbuscar_part_ba: part_mem_ocupada($pa)=$asignada"
				fi
				if [ $asignada -eq 1 ];then # Ya estaba asignada, esta no vale
					if [ $debug -eq 1 ];then	
						echo -e "\tbuscar_part_ba: Esta particion se ignora, ya estaba ocupada"
					fi
					
				else
					(( min_asumido_check = TAM_PART[$pa] - MEMORIA[$proceso_actual] ))
					if [ $min_asumido_check -lt 0 ];then
						if [ $debug -eq 1 ];then	
							echo -e "\tbuscar_part_ba: Particion indice $pa no cabe en el proceso indice $proceso_actual"
						fi
					else
						if [ $min_asumido_check -lt $min_asumido ];then
							min_asumido=$min_asumido_check
							pa_found=$pa
						fi
					fi
				fi
			done

			if [ $pa_found -eq -1 ];then
				if [ $debug -eq 1 ];then	
					echo -e "\tbuscar_part_ba: No se halla ninguna particion candidata!"
				fi
			fi
			if [ $debug -eq 1 ];then
				echo -e "\tbuscar_part_ba: Hemos hallado un hueco como MEJOR min_asumido=${min_asumido} en la particion ${pa_found}"
			fi
			encontrada_part=0
			for((pa=0 ; pa < $n_par ; pa++ ))
			do
				if [ $debug -eq 1 ];then	
					echo -e "\tbuscar_part_ba: Estamos en el proceso $proceso_actual. Particion $pa (Su tamano es de ${PART_SIZE[$pa]} y su total es de ${TAM_PART[$pa]}). El proceso ocupa una memoria de ${MEMORIA[$proceso_actual]}. Este proceso esta en estado ${ESTADO[$proceso_actual]} en la particion ${PART[$proceso_actual]}):"
				fi
				if [[ ${PART[$pa]} -gt -1 ]];then
					ninguno_en_memoria=0
				fi
				#if [[ ${EN_MEMO[$proceso_actual]} == Si ]] || [[ ${ESTADO[$proceso_actual]} == Acabado ]];then
				if [ $debug -eq 1 ];then
					echo -e "\tbusc_part_ba:MEMORIA[$proceso_actual]=${MEMORIA[$proceso_actual]}, TAM_PART[$pa]=${TAM_PART[$pa]}"
				fi
				if [[ ${ESTADO[$proceso_actual]} == Acabado ]];then
					
					break

				elif [[ $pa == $pa_found ]];then
					if [ $debug -eq 1 ];then
						echo -e "\tbuscar_part_ba: Candidata a ser particion ok"
					fi
					part_mem_ocupada $pa
				
					if [ $asignada -eq 0 ];then # Solo asigna en el caso que este libre la particion al proceso
						if [[ $debug == 1 || $debug2 == 1 ]];then
							echo "ba: Que es primera vez? $primera_vez"
						fi
						if [ $primera_vez -eq 1 ];then
							
							primera_vez=0
							encontrada_part=1
						fi
						
						if [[ $proc_elegido == -1 ]];then
							proc_elegido=$proceso_actual
						fi

						if [ $debug -eq 1 ];then	
							echo -e "\tbuscar_part_ba: OK! Asignamos la particion $pa al proceso $proceso_actual!!!"
						fi

						PART[$proceso_actual]=`expr $pa`
						EN_MEMO[$proceso_actual]="Si"
						ch_estado $proceso_actual 2 "busc_part_ba"
						encontrada_part=1
						gl_nueva_asignacion=1
						((i++))
						break
					fi
					
				else # El proceso no esta ni acabado y tampoco cabe en memoria
					
					((i++))
				fi
			done
			if [ $encontrada_part -eq 0 ];then
				if [ $debug -eq 1 ];then
					echo "busar_part_ba: Imposible hallar una particion para el proceso a analizar indice $proceso_actual. Nos largamos"
				fi
				break
			fi
		fi
	done
	if [ $debug -eq 1 ];then	
		pausaConIteraciones "buscar_part_ba: Saliendoo....."
	fi
}

buscar_particion_peor_ajuste() { # comprobamos si el proceso se puede meter en memoria
	# arg1: Numero de proceso ($1)
	local pa # variable local para particiones de memoria
	local pr # variable local para proceso actual
	local num_asignadas=0
	local proceso_actual # variable local para procesos que pueden ser analizados para ocupar memoria
	local max_asumido
	local max_asumido_check
	local pa_found # Es global
	local pr # variable local para procesos actuales
	local proceso_actual # variable local para procesos que pueden ser analizados para ocupar memoria
	local i
	local PROCESOS_DISPONIBLES_TIEMPO
	local primera_vez
	local encontrada_part
	primera_vez=1
	encontrada_part=0


	# Iteracion de liberacion, si todas las partciones estan ocupadas, no es necesario seguir buscando
	for((pa=0 ; pa < $n_par ; pa++ ))
	do
		part_mem_ocupada $pa
		if [[ $asignada == 1 ]];then
			(( num_asignadas++ ))
		fi
	done
	if [[ $num_asignadas -ge $n_par ]];then
		if [[ $debug == 1 ]];then
			echo "buscar_part_wa: Saliendo, todas las particiones estan ocupadas"
		fi
		return
	fi

	alguno_en_memoria # Comprueba y modifica la variable global gl_en_memoria
	gl_nueva_reasignacion=0
	gl_nueva_asignacion=0
	if [[ $gl_en_memoria == 0 ]];then
		gl_nueva_reasignacion=1
	fi

	proceso_actual=`expr $1`
	
	for((pr=0; pr < $num_proc; pr++ ))
	do
		if [ ${T_ENTRADA[$pr]} -le $tiempo_transcurrido ];then
			
			if [[ ${PART[$pr]} == -1 && ${ESTADO[$pr]} != "Finalizado" && ${ESTADO[$pr]} != "En Memoria" ]];then
				PROCESOS_DISPONIBLES_TIEMPO[$i]=`expr $pr`
				((i++))
				
			fi
			

		fi

	done

	if [ $debug -eq 1 ];then
		echo "####################### proc disponibles #######################"
	fi
	for proceso_disponible in "${PROCESOS_DISPONIBLES_TIEMPO[@]}"
	do
		if [ $debug -eq 1 ];then
			echo -e "\tproc_disponible=$proceso_disponible"
		fi
	done
	if [ $debug -eq 1 ];then
		echo "####################### END proc disponibles #######################"
	fi
	
	proceso_disponible=`expr $1`
	i=0
	proc_elegido=-1
	buscar_primer_proceso_asignado
	if [ $debug -eq 1 ];then	
		echo -e "\tbuscar_part_wa: buscar_primer_proceso_asignado()=$gl_asignado (-1=ninguno)"
	fi
	# Bucle para calcular el proceso que tiene el peor ajuste, es decir al que le sobre mas memoria libre en caso de estar asignado
	for proceso_disponible in "${PROCESOS_DISPONIBLES_TIEMPO[@]}"
	do
		proceso_actual=`expr $proceso_disponible`
		#TODO: Revisar que sin el siguiente condicional funciona todo ok
		#if [[ $gl_asignado -gt -1 && $proceso_actual -ge `expr $gl_asignado + $n_par` ]];then
			if [ $debug -eq 1 ];then	
				echo -e "\tbuscar_part_wa: FAKE saliendo, no podemos asignar más procesos ya que gl_asignado=${gl_asignado}, proc_disp=$proceso_disponible"
			fi
			#break
		#fi
		if [ $debug -eq 1 ];then
			echo "Estamos analizando proceso $proceso_actual"
			echo -e "\tbuscar_part_wa: Estamos analizando el proceso plausible $proceso_disponible"
			echo -e "\tbuscar_part_wa: Entrada con proceso indice ${proceso_actual} (Su tamano es ${MEMORIA[$proceso_actual]} y tiene la particion ${PART[$proceso_actual]})"
		fi
		if [ ${PART[$proceso_actual]} -gt -1 ];then # el proceso a analizar ya esta siendo ocupado por una particion
			# no hacer nada
			if [ $debug -eq 1 ];then	
				echo -e "\tbuscar_part_wa: Ya estaba asignada particion, no hacer nada"
			fi
			continue
		fi

		max_asumido=-1
		pa_found=-1
		# busca el primer candidato valido aunque no sea el mejor, osea el que mas desperdicia
		for((pa=0 ; pa < $n_par ; pa++ ))
		do
			part_mem_ocupada $pa

			if [ $asignada -eq 1 ];then # Ya estaba asignada, esta no vale
				if [ $debug -eq 1 ];then	
					echo -e "\tbuscar_part_wa: Esta particion se ignora, ya estaba ocupada"
				fi
			
			else
				#min_asumido=`expr ${TAM_PART[$pa]} - ${MEMORIA[$proceso_actual]}`
				(( max_asumido = TAM_PART[$pa] - MEMORIA[$proceso_actual] ))
				if [ $debug -eq 1 ];then	
					echo -e "\tbuscar_part_wa: Max asumido calculado es ${max_asumido}"
				fi
				if [ $max_asumido -lt 0 ];then
					if [ $debug -eq 1 ];then	
						echo -e "\tbuscar_part_wa: Particion indice $pa no cabe en el proceso indice $proceso_actual"
					fi
					max_asumido=-1
				else
					if [ $debug -eq 1 ];then	
						echo -e "\tbuscar_part_wa: Particion indice $pa es candidata para el proceso indice $proceso_actual"
					fi
					pa_found=$pa
					break
				fi
			fi
		done
		
		if [[ $max_asumido == -1 ]];then
			if [ $debug -eq 1 ];then
				echo -e "\tbuscar_part_wa: No existe ninguna particion libre o que quepa. No hace falta busscar mas"
				#encontrada_part=0
			fi
			#break
		else
			if [ $debug -eq 1 ];then
				echo -e "\tbuscar_part_wa: Hemos hallado un candidato de max_asumido=${max_asumido} en la particion ${pa_found}"
			fi
			max_asumido_check=$max_asumido
			
			for((pa=0 ; pa < $n_par ; pa++ ))
			do
				part_mem_ocupada $pa
				if [ $debug -eq 1 ];then
					echo -e "\tbuscar_part_wa: part_mem_ocupada($pa)=$asignada"
				fi
				if [ $asignada -eq 1 ];then # Ya estaba asignada, esta no vale
					if [ $debug -eq 1 ];then	
						echo -e "\tbuscar_part_wa: Esta particion se ignora, ya estaba ocupada"
					fi
					
				else
					(( max_asumido_check = TAM_PART[$pa] - MEMORIA[$proceso_actual] ))
					if [ $max_asumido_check -lt 0 ];then
						if [ $debug -eq 1 ];then	
							echo -e "\tbuscar_part_wa: Particion indice $pa no cabe en el proceso indice $proceso_actual"
						fi
					else
						if [ $max_asumido_check -gt $max_asumido ];then
							max_asumido=$max_asumido_check
							pa_found=$pa
						fi
					fi
				fi
			done

			if [ $pa_found -eq -1 ];then
				if [ $debug -eq 1 ];then	
					echo -e "\tbuscar_part_wa: No se halla ninguna particion candidata!"
				fi
			fi
			if [ $debug -eq 1 ];then
				echo -e "\tbuscar_part_wa: Hemos hallado un hueco como PEOR max_asumido=${max_asumido} en la particion ${pa_found}"
			fi
			encontrada_part=0
			for((pa=0 ; pa < $n_par ; pa++ ))
			do
				if [ $debug -eq 1 ];then	
					echo -e "\tbuscar_part_wa: Estamos en el proceso indice ${proceso_actual}. Particion $pa (Su tamano es de ${PART_SIZE[$pa]} y su total es de ${TAM_PART[$pa]}). El proceso ocupa una memoria de ${MEMORIA[$proceso_actual]}. Este proceso esta en estado ${ESTADO[$proceso_actual]} en la particion ${PART[$proceso_actual]}):"
				fi
				if [[ ${PART[$pa]} -gt -1 ]];then
					ninguno_en_memoria=0
				fi
				#if [[ ${EN_MEMO[$proceso_actual]} == Si ]] || [[ ${ESTADO[$proceso_actual]} == Acabado ]];then
				if [ $debug -eq 1 ];then
					echo -e "\tbusc_part_wa:MEMORIA[$proceso_actual]=${MEMORIA[$proceso_actual]}, TAM_PART[$pa]=${TAM_PART[$pa]}"
				fi
				if [[ ${ESTADO[$proceso_actual]} == Finalizado ]];then
					
					break

				elif [[ $pa == $pa_found ]];then
					if [ $debug -eq 1 ];then
						echo -e "\tbuscar_part_wa: Candidata a ser particion ok"
					fi
					part_mem_ocupada $pa
				
					if [ $asignada -eq 0 ];then # Solo asigna en el caso que este libre la particion al proceso
						if [[ $debug == 1 || $debug2 == 1 ]];then
							echo "wa: Que es primera vez? $primera_vez"
						fi
						if [ $primera_vez -eq 1 ];then
							
							primera_vez=0
							encontrada_part=1
						fi
						
						if [[ $proc_elegido == -1 ]];then
							proc_elegido=$proceso_actual
						fi

						if [ $debug -eq 1 ];then	
							echo -e "\tbuscar_part_wa: OK! Asignamos la particion $pa al proceso $proceso_actual!!!"
						fi

						PART[$proceso_actual]=`expr $pa`
						EN_MEMO[$proceso_actual]="Si"
						ch_estado $proceso_actual 2 "busc_part_wa"
						encontrada_part=1
						gl_nueva_asignacion=1
						((i++))
						break
					fi
					
				else # El proceso no esta ni acabado y tampoco cabe en memoria
					
					((i++))
				fi
			done
			if [ $encontrada_part -eq 0 ];then
				if [ $debug -eq 1 ];then
					echo "busar_part_wa: Imposible hallar una particion para el proceso a analizar indice $proceso_actual. Nos largamos"
				fi
				break
			fi
		fi
	done
	if [ $debug -eq 1 ];then	
		read -p "buscar_part_pa: Saliendoo....."
	fi
}

#selecciona el ajuste de los procesos en las particiones
refresca_particiones() {
	if [[ $gl_ajuste == "fa" ]];then
		buscar_particion_primer_ajuste $proc_rr
	elif [[ $gl_ajuste == "ba" ]];then
		buscar_particion_mejor_ajuste $proc_rr
	else
		buscar_particion_peor_ajuste $proc_rr
	fi
}

# Fuera la terminacion de procesos atendiendo a la rafaga restante A LO BESTIA
termina_procesos() {
	local i
	local ref_restante
	for((i=0 ; i<$num_proc ; i++))
	do
		raf_restante=${TIEMPO[$i]}

		if [[ $raf_restante == 0 && ${ESTADO[$i]} != "Finalizado" ]];then
			ch_estado $i 5 "termina_procesos"
		fi
	done
}


# Modifica las variables globales de la barra de tiempo
refresca_historico_ejecucion() {
	local resta=$quantum
	local espacios
	local t_print

	if [[ $gl_resta_por_quantum == 0 ]];then
		resta=$gl_tiempo_restar
	fi
	if [[ $gl_iteracion == 0 ]];then # No mostrar nunca la primera vez
		return
	fi
	# Prepara la cadena de impresion del histórico de ejecucion del programa
	if [[ $gl_tiempo_muerto == 1 ]];then
		espacios=$"\e[37;m"
	else
		espacios=$"\e[107;m"
	fi
	#variables que miden el terminal
	tcar="${cadena_color_nc[$c_barra]}"
	tpantalla=$(tput cols) 
	tpantalla=$(($tpantalla - 6))
	#gl_array_tiempos
	pcsoEjecutando=0
	for(( i=0 ; i < $num_proc ; i++ ))
		do
			if [[  "${ESTADO[$i]}" == "En Ejecucion"  ]]; then
				((pcsoEjecutando++))
				if [[ $pcsoEjecutando == 1 ]]; then
					break
				fi
			fi
		done

	

	
	len=${#gl_array_tiempos[@]}
	if [[ $pcsoEjecutando -eq 0 ]]; then
		gl_array_tiempos[ "$gl_iteracion" ]="-1"
	else
		gl_array_tiempos[ "$gl_iteracion" ]="$proc_rr"
	fi	


	#comprueba si se pasa del ancho en cada caracter
	if [[ ${#tcar} -lt $tpantalla ]]; then
		if [[ $gl_cambio_proceso -ge 1 ]];then
			contadorGAP=0
			#NOP

			if [[ $tiempo_transcurrido -gt 9 ]];then
				gl_cadena_tiempos[$c_barra]="${gl_cadena_tiempos[$c_barra]} $tiempo_transcurrido"
			else
				gl_cadena_tiempos[$c_barra]="${gl_cadena_tiempos[$c_barra]}  $tiempo_transcurrido"
			fi
			if [[ ${PROC[$proc_rr]} -lt 10 ]];then
				gl_cadena_proceso[$c_barra]="${gl_cadena_proceso[$c_barra]}${PROC_COLORS[${PROC[$proc_rr]}]}P0${PROC[$proc_rr]}"
				cadena_proceso_nc[$c_barra]="${cadena_proceso_nc[$c_barra]}P0${PROC[$proc_rr]}"
				if [[ $pcsoEjecutando -eq 0 ]]; then
					for (( i = 0; i < 3; i++ )); do
						gl_cadena_multiple_color[$c_barra]="${gl_cadena_multiple_color[$c_barra]}\e[107m "
						cadena_color_nc[$c_barra]="${cadena_color_nc[$c_barra]}_"
						tamaño_historico
					done	
				else
					for (( i = 0; i < 3; i++ )); do
						gl_cadena_multiple_color[$c_barra]="${gl_cadena_multiple_color[$c_barra]}${BG_COLORS[PROC[$proc_rr]]} "
						cadena_color_nc[$c_barra]="${cadena_color_nc[$c_barra]}X"
						tamaño_historico
					done	
				fi
			else
				gl_cadena_proceso[$c_barra]="${gl_cadena_proceso[$c_barra]}${PROC_COLORS[${PROC[$proc_rr]}]}P${PROC[$proc_rr]}"
				cadena_proceso_nc[$c_barra]="${cadena_proceso_nc[$c_barra]}P${PROC[$proc_rr]}"
				if [[ $pcsoEjecutando -eq 0 ]]; then
					for (( i = 0; i < 3; i++ )); do
						# NOP
						gl_cadena_multiple_color[$c_barra]="${gl_cadena_multiple_color[$c_barra]}\e[107m "
						cadena_color_nc[$c_barra]="${cadena_color_nc[$c_barra]}_"
						tamaño_historico
					done	
				else
					contadorGAP=0
					for (( i = 0; i < 3; i++ )); do
						# NOP
						gl_cadena_multiple_color[$c_barra]="${gl_cadena_multiple_color[$c_barra]}${BG_COLORS[PROC[$proc_rr]]} "
						cadena_color_nc[$c_barra]="${cadena_color_nc[$c_barra]}X"
						tamaño_historico
					done	
				fi
			fi
		else
			for (( i = 0; i < 3; i++ )); do
				gl_cadena_proceso[$c_barra]="${gl_cadena_proceso[$c_barra]} "
				cadena_proceso_nc[$c_barra]="${cadena_proceso_nc[$c_barra]} "
				tamaño_historico
				if [[ $pcsoEjecutando -eq 0 ]]; then # Color blanco
					gl_cadena_multiple_color[$c_barra]="${gl_cadena_multiple_color[$c_barra]}\e[107m "
					cadena_color_nc[$c_barra]="${cadena_color_nc[$c_barra]}_"
					tamaño_historico
				else # Color verde
					gl_cadena_multiple_color[$c_barra]="${gl_cadena_multiple_color[$c_barra]}${BG_COLORS[PROC[$proc_rr]]} "
					cadena_color_nc[$c_barra]="${cadena_color_nc[$c_barra]}X"
					tamaño_historico
				fi
			done
			#imprime el tiempo transcurrido cuando no hay un proceso en ejecución	
			if [[ $pcsoEjecutando -eq 0 ]] && [[ $contadorGAP == 0 ]]; then
					((contadorGAP++))
					if [[ $tiempo_transcurrido -gt 9 ]];then
						gl_cadena_tiempos[$c_barra]="${gl_cadena_tiempos[$c_barra]} $tiempo_transcurrido"
					else
						if [[ $tiempo_transcurrido -eq 1 ]]; then
							gl_cadena_tiempos[$c_barra]="${gl_cadena_tiempos[$c_barra]}  0"
						else
							gl_cadena_tiempos[$c_barra]="${gl_cadena_tiempos[$c_barra]}  $tiempo_transcurrido"
						fi
						
					fi
				else
					gl_cadena_tiempos[$c_barra]="${gl_cadena_tiempos[$c_barra]}   "
				fi
		fi
	else
		#cambia de linea y de variable del vector
		((c_barra++))
		tcar="${cadena_color_nc[$c_barra]}"
		if [[ $gl_cambio_proceso -ge 1 ]];then
			if [[ $tiempo_transcurrido -gt 9 ]];then
				gl_cadena_tiempos[$c_barra]="${gl_cadena_tiempos[$c_barra]} $tiempo_transcurrido"
			else
				gl_cadena_tiempos[$c_barra]="${gl_cadena_tiempos[$c_barra]}  $tiempo_transcurrido"
			fi
			if [[ ${PROC[$proc_rr]} -lt 10 ]];then
				gl_cadena_proceso[$c_barra]="${gl_cadena_proceso[$c_barra]}${PROC_COLORS[${PROC[$proc_rr]}]}P0${PROC[$proc_rr]}"
				cadena_proceso_nc[$c_barra]="${cadena_proceso_nc[$c_barra]}P0${PROC[$proc_rr]}"
				for (( i = 0; i < 3; i++ )); do
					gl_cadena_multiple_color[$c_barra]="${gl_cadena_multiple_color[$c_barra]}${BG_COLORS[PROC[$proc_rr]]} "
					cadena_color_nc[$c_barra]="${cadena_color_nc[$c_barra]}X"
					tamaño_historico
				done
			else
				gl_cadena_proceso[$c_barra]="${gl_cadena_proceso[$c_barra]}${PROC_COLORS[${PROC[$proc_rr]}]}P${PROC[$proc_rr]}"
				cadena_proceso_nc[$c_barra]="${cadena_proceso_nc[$c_barra]}P${PROC[$proc_rr]}"
				for (( i = 0; i < 3; i++ )); do
					gl_cadena_multiple_color[$c_barra]="${gl_cadena_multiple_color[$c_barra]}${BG_COLORS[PROC[$proc_rr]]} "
					cadena_color_nc[$c_barra]="${cadena_color_nc[$c_barra]}X"
					tamaño_historico
				done
			fi
		else
			for (( i = 0; i < 3; i++ )); do
				gl_cadena_proceso[$c_barra]="${gl_cadena_proceso[$c_barra]} "
				cadena_proceso_nc[$c_barra]="${cadena_proceso_nc[$c_barra]} "
				gl_cadena_tiempos[$c_barra]="${gl_cadena_tiempos[$c_barra]} "
				gl_cadena_multiple_color[$c_barra]="${gl_cadena_multiple_color[$c_barra]}${BG_COLORS[PROC[$proc_rr]]} "
				cadena_color_nc[$c_barra]="${cadena_color_nc[$c_barra]}X"
				tamaño_historico
			done	
		fi

	fi		

	
}

#comprueba si se ha sobrepasado el tamaño de la barra
tamaño_historico(){
	if [[ ${#tcar} -ge $tpantalla ]]; then
		((c_barra++))
		tcar="${cadena_color_nc[$c_barra]}"
	fi
}



# Refresca la ventana de ejecucion rotativa RR asi como su puntero.
# Arg1: Ignorar medio quantum, es decir, no hace rotacion si estamos en mitad de un quantum
calcular_rr_ventana() {
	local en_memo
	local i=0
	local cambiada_ventana=0
	local cambiada_ventana_inicio=0
	local backup_proc_max
	local backup_proc_min
	local backup_proc_rr
	local backup_inicio_proc_rr=$proc_rr
	local found=0
	local ignorar_medio_quantum=$1
	
	gl_nuevo_puntero=0 # Asuncion de que no se movera el puntero de ventana

	if [[ $ignorar_medio_quantum == 0 && $gl_medio_quantum == 1 ]];then 
		return
	fi

	# Revisar condicion de salida, no podemos rotar si el proceso actual le quedan rafagas y aun queda quantum restante
	if [[ $proc_rr -ge 0 && ${TIEMPO[$proc_rr]} -gt 0 && $gl_quantum_restante -gt 0 ]];then
		if [[ $gl_debug == 1 ]];then
			echo "(cal_rr_vent): -------------------- NO HACER NADA CON PROC ${proc_rr}, AUN SE ESTA EJECUTANDO Y QUEDAN RAFAGAS -------------------------"
		fi
		return
	fi

	backup_proc_min=$proc_min_rr
	backup_proc_max=$proc_max_rr
	proc_min_rr=-1
	proc_max_rr=-1


	for en_memo in ${PART[@]} # PART guarda la particion actual de memoria, -1 si no esta en ninguna
	do
		if [[ $en_memo -ge 0 && $proc_min_rr == -1 && ${ESTADO[$i]} != "Finalizado" ]];then
			proc_min_rr=$i
		fi
		if [[ $en_memo == -1  && ${ESTADO[$i]} != "Finalizado" && $proc_max_rr -gt -1 ]];then
			break
		fi
		if [[ $en_memo -ge 0 ]];then
			proc_max_rr=$i
		fi
		((i++))
	done
	if [[ $proc_rr == -1 ]];then
		proc_rr=$proc_min_rr
	else

		if [[ $proc_min_rr == $proc_max_rr ]];then
			proc_rr=$proc_min_rr
		
		fi
	
		if [[ $proc_rr -gt $proc_max_rr ]];then
			proc_rr=$proc_min_rr
		fi
		if [[ $debug == 1 || $debug2 == 1 ]];then
			echo "------------------------gl_nueva_reasig= ${gl_nueva_reasignacion}----------------------------"
		fi
		if [[ $gl_nueva_reasignacion == 1 ]];then # Caso especial en que se reasignan las particiones de memoria en nueva nueva ventana y se debe inicializar el contador de round robin.
			proc_rr=$proc_min_rr
		fi

	fi
	
	if [[ $proc_max_rr -ne $backup_proc_max ]];then
		if [[ $debug == 1 || $debug2 == 1 ]];then
			echo "--------------------------CAMBIADA ventana al final!!!!!!-------------------------------------"
		fi
		cambiada_ventana=1
	fi
	if [[ $proc_min_rr -ne $backup_proc_min ]];then
		if [[ $debug == 1 || $debug2 == 1 ]];then
			echo "--------------------------CAMBIADA ventana al inicio!!!!!!-------------------------------------"
		fi
		cambiada_ventana_inicio=1
	fi
	if [[ $cambiada_ventana == 1 && $gl_nueva_asignacion == 1 ]];then
		proc_rr=$proc_min_rr
	fi
	if [[ $proc_rr -lt $proc_min_rr ]];then
		proc_rr=$proc_min_rr
	fi
	if [[ $proc_rr -gt $proc_max_rr ]];then
		proc_rr=$proc_min_rr
	fi
	if [[ $cambiada_ventana_inicio == 1 ]];then
		#ESTADO[$proc_rr]="Ejecucion"
		#gl_proc_ejec=$proc_rr
		#echo "-----------------> CHANGED STATE to Execution (calc_rr_ventana) there's a window change <--------------------"
		#read -p "<Press enter deleteme 1>"
		if [[ $gl_debug == 1 ]];then
			echo "calc_rr_vent: No se ejecuta nada aqui, DISABLED"
		fi
	fi
	#gl_proc_ejec=$proc_rr
	if [[ $backup_inicio_proc_rr != $proc_rr ]];then
		gl_nuevo_puntero=1
	fi
	if [[ $gl_debug == 1 ]];then
		echo "calc_rr_vent FIN: Backup ventana: [${backup_proc_min},${backup_proc_max}], nueva ventana [${proc_min_rr},${proc_max_rr}] puntero a ${proc_rr}, puntero global a ${gl_proc_ejec}, nueva asignacion? ${gl_nueva_asignacion}, cambiada posicion de puntero? ${gl_nuevo_puntero} cambiada ventana? ${cambiada_ventana}, cambiada ventana inicial? ${cambiada_ventana_inicio}"
	fi
}


ejecuta_rr_iteracion() {
	local instantes_restantes
	local estado
	local i
	local tiempo_backup
	local medio_quant=1
	local resto
	local resta_unidades=$quantum
	local espacios

	if [[ $gl_resta_por_quantum == 0 ]];then
		resta_unidades=$gl_tiempo_restar
	fi

	if [[ $proc_rr == -1 ]];then
		#Nada que calcular, es imposible ejecutar procesos si no hay ventana de ejecución valida
		if [[ $gl_debug == 1 ]];then
			echo "ej_rr_it: Imposible ejecutar procesos sin ventana de ejecucion activa"
			#read -p "intro"
		fi
		return # Salida forzada de funcion
	fi
	

	instantes_restantes=${TIEMPO[$proc_rr]}

			instantes_restantes=`expr ${TIEMPO[$proc_rr]} - $resta_unidades`
			if [[ $gl_debug == 1 ]];then
				echo "(ejec_rr_iter)+++++++++++++++++++ Se restan ${resta_unidades} unidades al timempo que le queda al proceso en curso ${proc_rr} +++++++++++++++++++++++++"
			fi
			
			
			actualiza_quantum_tiempos 1 # 1: Tiene en cuenta la consumicion de instantes. Modifica las variables globales gl_medio_quantum y gl_quantum_restante
			medio_quant=0
		#fi
		if [[ $instantes_restantes -lt 0 ]];then
			return
		fi
		if [[ $medio_quant == 0 ]];then
			ch_estado $proc_rr 3 "ejec_rr_iter"
			TIEMPO[$proc_rr]=$instantes_restantes

if [[ 1 == 0 ]];then
			# Prepara la cadena de impresion del histórico de ejecucion del programa
			espacios=${BG_COLORS[$proc_rr]}
			
			#espacios=${bg_color_red}
			for(( i=0 ; i<$resta_unidades ; i++))
			do
				espacios="${espacios}  "
			done
			gl_cadena="${gl_cadena}${color_default}P${PROC[$proc_rr]}:${espacios}${color_default}(I=${tiempo_transcurrido})"
			gl_cadena_simple="${gl_cadena_simple}${PROC_COLORS[${PROC[$proc_rr]}]}P${PROC[$proc_rr]}${color_default}(I=${tiempo_transcurrido})"
			
			gl_cadena_nocolor="${gl_cadena_nocolor}P${PROC[$proc_rr]}(I=${tiempo_transcurrido})" # Esta se usa para imprimir en fichero
fi
			gl_proc_ejec=$proc_rr
			gl_uno_en_ejecucion=1
			if [[ $gl_debug == 1 ]];then
				echo "-----------------> CHANGED STATE to Execution for process index ${proc_rr} (exe_rr_iter) due is required <--------------------"
			fi
			#read -p "<Press enter deleteme 2>"
			
			#echo "tiempo_transcurrido es ${tiempo_transcurrido} y quanto es ${quantum}. Actualizamos tiempo_ejec"
			
		fi
	
	
	if  [ -z "${CONTEXTO[$proc_actual]}" ];then
		CONTEXTO[$proc_rr]=1
	else
		CONTEXTO[$proc_rr]=`expr ${CONTEXTO[$proc_rr]} + 1`
	fi
	
	
	#if [[ $gl_medio_quantum == 0 ]];then
		for((i=$proc_min_rr; i<=$proc_max_rr ; i++))
		do
			estado=${ESTADO[$i]}
			if [[ $i == $proc_rr ]];then
				continue
			fi
			#echo "Vamos a poner en pausa!!!!!!!!!!!!!!!!!! TIEMPO_EJEC[$i]=${TIEMPO_EJEC[$i]}, proceso esta en estado ${estado}!!!!!!!!!!!!!!!!!!!!!!!!!"
			if [[ ${estado} != "Finalizado" && ${TIEMPO_EJEC[$i]} -gt 0 ]];then
				#echo "EN PAUSA SI"
				ch_estado $i 4 "ejec_rr_iter"
			fi
		done
	#fi
}

# Fuerza poner un nuevo proceso en ejecucion asumiendo la ventana de ejecucion y luego asegurandose que ninguno mas estara en ejecucion
ejecuta_segun_ventana() {
	local i
	uno_en_ejecucion
	if [[ $gl_uno_en_ejecucion == 1 ]];then
		if [[ $gl_debug == 1 ]];then
			echo "ej_se_ve: Ya existia uno en ejecución, saliendo.............."
		fi
		return
	fi
	if [[ $gl_proc_ejec -gt -1 && $gl_proc_ejec != $proc_rr && $proc_rr -gt -1 ]];then
		ch_estado $proc_rr 5 "ej_seg_ventana (1/2)"
		#if [[ $gl_debug == 1 ]];then
		#	echo "-----------------> CHANGED STATE to Execution process index ${proc_rr} (ej_se_ve) <--------------------"
		#fi
		gl_proc_ejec=$proc_rr
		for ((i=0; i<$num_proc; i++))
		do
			if [[ $i != $proc_rr && ${ESTADO[$i]} == "En Ejecucion" ]];then
				# Si no es el que acabmoa de poner a ejecutar y no esta o bien acabado o otra cosa pondremos en pausa o terminado
				if [[ ${TIEMPO[$i]} -gt 0 ]];then
					ch_estado $i 4 "ej_seg_ventana"
				else
					ch_estado $i 5 "ej_seg_ventana (2/2)"
				fi
				
			fi
		done
	fi


}

# Actualiza el puntero proc_rr con el siguiente que le tocaria a ejecutar (o -1 si no tiene nada posible que ejecutar)
buscar_siguiente_a_ejecutar() {
	local i
	local backup_proc_rr=$proc_rr
	local found=0

	if [[ $proc_rr == -1 ]];then #No esta inicializada la ventana o bien se ha terminado e ejecutar todo el algoritmo
		return
	fi
	#Recorremos el primer trozo, de donde estábamos hasta el final
	print_linea_estados
	for (( i=$backup_proc_rr+1; i<=$proc_max_rr; i++ ))
	do
		if [[ ${ESTADO[$i]} != "Finalizado" ]];then
			proc_rr=$i
			found=1
			#echo "(calc_rr_ventana)Found in 1!!!!!!!!!!!!!!!"
			break # Faltaba esto aqui
		fi
	done
	if [[ $found == 0 ]];then
		#Recorremos el segundo trozo, que seria en caso de no encontrar nada, de principio a puntero
		for (( i=$proc_min_rr; i<=$proc_rr; i++ ))
		do
			if [[ ${ESTADO[$i]} != "Finalizado" ]];then
				proc_rr=$i
				found=1
				#echo "(calc_rr_ventana)Found in 2!!!!!!!!!!!!!!!!!!!!"
				break # Faltaba esto aqui
			fi
		done
	fi
	if [[ $gl_debug == 1 ]];then
		echo "buscar_sig_a_ejecutar: Refrescado puntero ventana con inteligencia, pasado puntero de ${backup_proc_rr} (Estado ${ESTADO[$backup_proc_rr]}) -> ${proc_rr} (Estado ${ESTADO[$proc_rr]})"
	fi
	if [[ $found == 0 ]];then
		if [[ $gl_debug == 1 ]];then
			echo "************************* CASO EXTREMO ******************************, ventana de ejecucion con procesos todos terminados!!!!"
		fi
		proc_rr=-1
		return
	fi
}

# Actualiza estados de fuera de sistema a en buffer cuando pueden entrar por tiempo de llegada
actualiza_estados_buffer() {
	local i
	local t_entrada
	i=0
	for t_entrada in ${T_ENTRADA[@]}
	do
		if [[ ${ESTADO[$i]} == "Fuera de Sistema" && $t_entrada -le $tiempo_transcurrido ]];then
			ch_estado $i 1 "act_est_buff"
		fi
		((i++))
	done
}

# Refresca la var globla proc_rr en un caso especial que se produce cuando no tenemos ventana de ejecucion y no hay puntero asignado y ya existen procesos acabados
refrescar_deadlock() {
	local detectado_acabado
	local alguno_en_memoria
	local ultimo_acabado
	local i
	detectado_acabado=0
	alguno_en_memoria=0
	
	for ((i=0; i<$num_proc; i++))
	do
		if [[ ${ESTADO[$i]} == "Finalizado" ]];then
			detectado_acabado=1
			ultimo_acabado=$i
		fi
		#echo "part[$i]= ${PART[$i]}"
		if [[ ${PART[$i]} -ge 0 ]];then
			alguno_en_memoria=1
		fi
		
	done
	#echo "alguno_en_memoria=${alguno_en_memoria}, detectado_acabado=${detectado_acabado}"
	if [[ $alguno_en_memoria == 0 && $detectado_acabado == 1 ]];then
		proc_rr=`expr $ultimo_acabado + 1`

		if [[ $proc_rr -ge $num_proc ]];then
			proc_rr=-1
		fi
		proc_min_rr=$proc_rr
		proc_max_rr=$proc_rr
	fi
}

# Cambia la variable global gl_rocesos_terminados contando los que estan acabados
refresca_procesos_terminados() {
	local estado
	gl_procesos_terminados=0
	for estado in ${ESTADO[@]}
	do
		if [[ $estado == "Finalizado" ]];then
			((gl_procesos_terminados++))
		fi
	done
}

refresca_tiempos_formula() {
	local estado
	local i=0
	local back_valor

	for (( i=0; i<$num_proc; i++ ))
	do
		#T_RETORNO[$i]=`expr ${gl_iteracion} - $T_ENTRADA[$i]}`
		if [[ ${ESTADO[$i]} == "En Memoria" || ${ESTADO[$i]} == "En Espera" || ${ESTADO[$i]} == "En Pausa" || ${ESTADO[$i]} == "En Ejecucion" ]];then
			back_valor=${T_RETORNO[$i]}
			T_RETORNO[$i]=`expr $gl_iteracion - ${T_ENTRADA[$i]}`
			if [[ ${T_RETORNO[$i]} -lt $back_valor ]];then
				T_RETORNO[$i]=$back_valor
			fi

			if [[ $debug3 == 1 ]];then
	   			echo "(refr_tiempos) -> Se modifica T_RETORNO[$i] a ${T_RETORNO[$i]}"
	   		fi
				
		fi
	done

	for (( i=0; i<$num_proc; i++ ))
	do
		if [[ ${ESTADO[$i]} == "En Memoria" || ${ESTADO[$i]} == "En Espera" || ${ESTADO[$i]} == "En Pausa" ]];then
			back_valor=${T_ESPERA[$i]}
			(( T_ESPERA[$i]+=$gl_tiempo_restar ))
			#T_ESPERA[$i]=`expr ${TIEMPO_PARADO[$i]} - ${TIEMPO_EJEC[$i]}`
			
			if [[ ${T_ESPERA[$i]} -lt $back_valor ]];then
				T_ESPERA[$i]=$back_valor
			fi
			if [[ T_ESPERA[$i] -gt $gl_iteracion ]];then
				T_ESPERA[$i]=$gl_iteracion
			fi
			if [[ $debug3 == 1 ]];then
	   			echo "(refr_tiempos) -> Se incrementa T_ESPERA[$i] de $back_valor a ${T_ESPERA[$i]}"
	   		fi

		fi
	done

	if [[ $debug3 == 1 ]];then
		pausaConIteraciones "Fin refresca_tiempos_formula"
	fi
}

refresca_tiempos() {
	local estado
	local i=0
	
	for estado in "${ESTADO[@]}"
	do
		if [[ 1 == 0 && ( $estado == "En Ejecucion" ) ]];then
	   		TIEMPO_EJEC[$i]=`expr ${TIEMPO_EJEC[$i]} + $gl_incr_tiempo`
	   		if [[ $debug3 == 1 ]];then
	   			echo "(refr_tiempos) -> Se incrementa TIEMPO_EJEC[$i] a ${TIEMPO_EJEC[$i]}"
	   		fi
	   		
	   	fi
	   	if [[ 1 == 0 && ( $estado == "En Memoria" || $estado == "En Espera" || $estado == "En Pausa" ) ]];then
	   		TIEMPO_PARADO[$i]=`expr ${TIEMPO_PARADO[$i]} + $gl_incr_tiempo`
	   		if [[ $debug3 == 1 ]];then
	   			echo "(refr_tiempos) -> Se incrementa TIEMPO_PARADO[$i] a ${TIEMPO_PARADO[$i]}"
	   		fi
	   		
	   	fi
	   	(( i++ ))
	done

	for (( i=0; i<$num_proc; i++ ))
	do
		if [[ ${ESTADO[$i]} == "En Memoria" || ${ESTADO[$i]} == "En Espera" || ${ESTADO[$i]} == "En Pausa" || ${ESTADO[$i]} == "En Ejecucion" ]];then
			T_RETORNO[$i]=`expr $gl_iteracion - ${T_ENTRADA[$i]}`
			if [[ $debug3 == 1 ]];then
	   			echo "(refr_tiempos) -> Se modifica T_RETORNO[$i] a ${T_RETORNO[$i]}"
	   		fi
				
		fi
		if [[ ${ESTADO[$i]} == "En Memoria" || ${ESTADO[$i]} == "En Espera" || ${ESTADO[$i]} == "En Pausa" ]];then
			T_ESPERA[$i]=`expr ${TIEMPO_PARADO[$i]} - ${TIEMPO_EJEC[$i]}`
			if [[ $debug3 == 1 ]];then
	   			echo "(refr_tiempos) -> Se modifica T_ESPERA[$i] a ${T_ESPERA[$i]}"
	   		fi

		fi
	done
	if [[ $debug3 == 1 ]];then
		pausaConIteraciones "Fin refresca_tiempos"
	fi
}

refresca_tiempos_de_ejecucion() {
	local estado
	local i=0
	for estado in "${ESTADO[@]}"
	do
	   	
	   	if [[ $estado == "En Ejecucion"  ]];then
			TIEMPO_EJEC[$i]=`expr ${TIEMPO_EJEC[$i]} + ${gl_tiempo_restar}`
		
			if [[ $debug3 == 1 ]];then
				echo "-------------Refrescado TIEMPO_EJEC[${i}] a ${TIEMPO_EJEC[$i]} unidades---------------------"
			fi
		fi
		(( i++ ))

	done
	if [[ $debug3 == 1 ]];then
		pausaConIteraciones "------------- SALIENDO de refresca_tiempos_de_ejecucion ---------------------"
	fi
}

refresca_tiempos_de_espera() {
	local estado
	local i=0
	for estado in "${ESTADO[@]}"
	do
	   	
	   	if [[ $estado == "En Memoria" || $estado == "En Espera" || $estado == "En Pausa" ]];then
			TIEMPO_PARADO[$i]=`expr ${TIEMPO_PARADO[$i]} + ${gl_tiempo_restar}`
		
			if [[ $debug3 == 1 ]];then
				echo "-------------Refrescado TIEMPO_PARADO[${i}] a ${TIEMPO_PARADO[$i]} unidades---------------------"
			fi
		fi
		(( i++ ))

	done
	if [[ $debug3 == 1 ]];then
		pausaConIteraciones "------------- SALIENDO de refresca_tiempos_de_espera ---------------------"
	fi
}



refresca_tiempos_de_retorno() {
	local estado
	local i=0
	for estado in "${ESTADO[@]}"
	do
		
		T_RETORNO[$i]=`expr ${TIEMPO_EJEC[$i]} - ${T_ENTRADA[$i]}`

		if [[ ${T_RETORNO[$i]} -lt 0 ]];then
			T_RETORNO[$i]=0
		fi
		if [[ $debug3 == 1 ]];then
			echo "-------------Refrescado T_RETORNO[${i}] a ${T_RETORNO[$i]} unidades---------------------"
		fi
		(( i++ ))
	#fi
	done
	if [[ $debug3 == 1 ]];then
			pausaConIteraciones "------------- SALIENDO ---------------------"
	fi
}

refresca_tiempo_final() {
	local i
	for ((i=0; i<$num_proc; i++))
	do
		if [[ ${ESTADO[$i]} != "Finalizado" ]];then
			(( TIEMPO_FIN[$i]+=$gl_incr_tiempo ))
		fi
	done
}


comprueba_tiempo_muerto() {
	gl_tiempo_muerto=1
	for ((i=0; i<$num_proc; i++))
	do
		#echo "TIEMPO MUERTO: Revisando proceso $i, está en stado ${ESTADO[$i]}, con un tiempo de entrada de ${T_ENTRADA[$i]} y estamos en el instante $tiempo_transcurrido..."
		if [[ ${ESTADO[$i]} != "Finalizado" && ${T_ENTRADA[$i]} -le $tiempo_transcurrido ]];then
			gl_tiempo_muerto=0
			return
		fi
	done

}
# Modifica la variable global gl_en_memoria y nos dice si de todos los procesos hay alguno o no asignado a una particion
alguno_en_memoria() {
	gl_en_memoria=0
	for en_memo in ${PART[@]}
	do
		if [[ en_memo -gt -1 ]];then
			gl_en_memoria=1
			break
		fi
	done
}

# Modifica la variable global gl_alguno_en_ejecucion y nos dice si de todos los procesos hay alguno o no en ejecucion (cuenta los que estan ejecucion)
alguno_en_ejecucion() {
	local estado
	gl_alguno_en_ejecucion=0
	for estado in ${ESTADO[@]}
	do
		if [[ estado == "En Ejecucion" ]];then
			(( gl_alguno_en_ejecucion++ ))
		fi
	done
}

#$1: el indice de proceso
#$2: el estado nuevo (en numero) (0..5)
#$3: una frase para imprimir por pantalla en caso de modo debug activo
ch_estado() {
	local ESTADOS=("Fuera de Sistema" "En Espera" "En Memoria" "En Ejecucion" "En Pausa" "Finalizado")
	local ind=$1
	local ind_state=$2
	local phrase=$3
	local new_state=${ESTADOS[$ind_state]}
	local old_state=${ESTADO[$ind]}
	local back_tiempo_stop
	local back_tiempo_ejec
	local cambiado=0
	

	if [[ $old_state != $new_state && $gl_revisado_cambio_de_estado == 0 ]];then
		# Nos aseguramos que solo hara esto una vez por iteracion del algoritmo principal, en el momento que haya un solo cambio de estado
		gl_cambio_de_estado=1
		gl_revisado_cambio_de_estado=1
		if [[ $debug3 == 1 ]];then
			echo "	*********************************************************************************************"
			echo "	-----------------------------> DETECTADO CAMBIO DE ESTADO GLOBAL <---------------------------"
			echo "	*********************************************************************************************"
		fi
	fi

	if [[ $gl_debug == 1 ]];then
		if [[ $old_state == "" ]];then
			echo "----------------> INICIO DE ESTADO (${phrase}) con ${new_state} al proc indice ${ind} <------------------------------------------------------------------"
		else
			echo "----------------> CAMBIO DE ESTADO (${phrase}) de proc indice ${ind} de ${old_state} -> ${new_state} <-----------------------------"
		fi
	fi
	
	if [[ $old_state == "En Ejecucion" && $new_state == "Finalizado" ]];then
		
		PART[$ind]=-1 # Hay que liberar esta particion!
	fi
	
	ESTADO[$ind]=$new_state
	back_tiempo_ejec=${TIEMPO_EJEC[$ind]}
	back_tiempo_stop=${TIEMPO_PARADO[$ind]}
	if [[ $old_state == "Fuera de Sistema" && $new_state == "En Espera" ]];then
		#(( T_ESPERA[$ind]+=$gl_tiempo_restar ))
		cambiado=1
	fi


	# Deteccion de cambio de proceso que se ejecuto la ultima vez
	if [[ $new_state == "En Ejecucion" && $gl_ultimo_proceso_ejecucion != $ind ]];then
		if [[ $debug3 == 1 ]];then
			echo "----------------------------------------------------------------------------"
			echo "---------                    Detectado cambio de proceso a ejecucion! indice $ind             -----------"
			echo "-----------------------------------------------------------------------------"
		fi
		gl_cambio_proceso=1
		gl_ultimo_proceso_ejecucion=$ind
	fi
	if [[ $gl_cambio_proceso != 1 ]];then
		gl_cambio_proceso=0
	fi
	if [[ $debug3 == 1 && $cambiado == 1 ]];then
		echo "-------------->Actualizado TIEMPO_EJEC[$ind] de $back_tiempo_ejec a ${TIEMPO_EJEC[$ind]} <----------------------"
		echo "-------------->Actualizado TIEMPO_PARADO[$ind] de $back_tiempo_stop a ${TIEMPO_PARADO[$ind]} <----------------------"
	fi

}

# Compra la ejecucion actual con la enterior y modifica la variable global gl_cambio_de_estado si no ha habido ningun cambio
detecta_cambio_estados() {
	gl_cambio_de_estado=0
	gl_cambio_ejecucion=1

	for ((i=0; i<$num_proc; i++))
	do
		if [[ ${ESTADO[$i]} != ${ESTADOS_ANTERIORES[$i]} ]];then
			gl_cambio_de_estado=1
			break
		fi	
	done
	for ((i=0; i<$num_proc; i++))
	do
		if [[ ${ESTADO[$i]} == "En Ejecucion" ]];then
			if [[ ${ESTADO[$i]} == ${ESTADOS_ANTERIORES[$i]}  ]]; then
				gl_cambio_ejecucion=0
			fi
		fi	
	done

	# Refrescar la var ESTADOS_ANTERIORES
	for ((i=0; i<$num_proc; i++))
	do
		ESTADOS_ANTERIORES[$i]=${ESTADO[$i]}
	done
}
 
# Detecta si hay 2 (o más) procesos marcados como ejecucion y en caso de haberlos, marca como En Pausa o Acabado (segun convenga) el que no este en el puntero de ejecucion
corrige_estados_ejecucion() {
	local i
	local en_ejecucion=0

	
	gl_uno_ha_terminado=0
	for ((i=0; i<$num_proc; i++))
	do
		if [[ ${ESTADO[$i]} == "En Ejecucion" ]];then
			(( en_ejecucion++ ))
			
		fi
		
	done

	if [[ en_ejecucion -gt 1 ]];then # Hay 2 o mas....
		for ((i=0; i<$num_proc; i++))
		do
			if [[ ${ESTADO[$i]} == "En Ejecucion" && $gl_proc_ejec != $i ]];then

				if [[ ${TIEMPO[$i]} -le 0 ]];then # Esta terminado
					ch_estado $i 5 "corrige_estados_ejecucion" # -> Acabado
					gl_uno_ha_terminado=1
				else
					ch_estado $i 4 "corrige_estados_ejecucion" # -> En Pausa
				fi
			
			fi
		
		done
	fi
}

# Intenta detectar y corregir un estado extraño que se da en aglunos casos en el que se refresca de golpe todas las particiones de memoria a una nueva tangada y el estado se queda En Memoria y no en ejecucion
corrige_estado_especial() {
	alguno_en_ejecucion
	# esto es lo que impirmia de mas echo "gl_alguno_en_ejecucion=$gl_alguno_en_ejecucion"
	if [[ $gl_alguno_en_ejecucion == 0 && ${ESTADO[$proc_rr]} == "En Memoria" ]];then # No existe proceso en ejecucion y el actual de ventana esta En Memoria, debe ponerse en Ejecucion
		ch_estado $proc_rr 3 "corrige_estado_especial"
	fi
}


# Comprueba que el primer proceso que se esta ejecutando ha agotado su tiempo y en caso de ser asi, refresca la ventana y realiza el cambio de estado sin modificar los tiempos
anticipa_siguiente_estado_ejecucion() {
	local i
	
	if [[ $proc_rr == -1 ]];then # No hacer nada
		return
	fi

	# Busca el primero en ejecucion en variable $gl_primero_en_ejecucion
	primero_en_ejecucion
	i=$gl_primero_en_ejecucion
	if [[ $gl_debug == 1 ]];then
		echo "!!!!!!!!!!!!!! anticipa: primero_ejec=${i}, su tiempo es ${TIEMPO[$i]}"
	fi

	# Si hay un proceso en ejecucion, no queda quantum restante y el puntero de ventana es distinto al de ejecucion hemos de permitir la rotacion
	if [[ $i -ge 0 && $gl_quantum_restante == 0 && ${TIEMPO[$i]} -gt 0 && $proc_rr != $i ]];then

		if [[ $gl_debug == 1 ]];then
			echo "!!!!!!!!!!!!!! anticipa por no finalizacion: primero_ejec=${i}, proc_rr=${proc_rr}"
		fi
		ch_estado $proc_rr 3 "anticipa_sig_estado" # a ejecutar
		gl_proc_ejec=$proc_rr
		# Reiniciamos el quantum
		gl_quantum_restante=$quantum 
		gl_medio_quantum=0
		# Llama aqui para asegurarse que no existan mas de uno en ejecucion, haciendo caso siempre a los punteros de ejecucion de la ventana
		corrige_estados_ejecucion
		return
	fi
	if [[ ( $i -ge 0 && ${TIEMPO[$i]} == 0 ) || ( $gl_quantum_restante == 0 && ${TIEMPO[$i]} -gt 0 ) ]];then # Hay uno en ejecucion y su rafaga está agotada o bien no queda quantum a ejecutar y el proceso aun le quedan rafagas
		# Provocar iteracion RR obligada
		
		#if [[ $gl_quantum_restante == 0 ]];then
			if [[ $gl_debug == 1 ]];then
				echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
				echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!RR: Nuevo salto forzado!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
				echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
			fi
			buscar_siguiente_a_ejecutar
			refresca_particiones

		if [[ $gl_debug == 1 ]];then
			echo "!!!!!!!!!!!!!! anticipa por finalizado: primero_ejec=${i}, proc_rr=${proc_rr}"
		fi
		if [[ ${TIEMPO[$proc_rr]} == 0 ]];then
			#tabla_ejecucion
			ch_estado $proc_rr 5 "anticipa_sig_estado" # a terminado
			#echo "Gooool"
			#tabla_ejecucion
			# Reiniciamos el quantum
			gl_quantum_restante=$quantum 
			gl_medio_quantum=0
			
			corrige_estado_especial
			# Llama aqui para asegurarse que no existan mas de uno en ejecucion, haciendo caso siempre a los punteros de ejecucion de la ventana
			corrige_estados_ejecucion
			refresca_particiones
			calcular_rr_ventana
			


			gl_primera_vez=0
			refresca_procesos_terminados
			refresca_tiempo_final

			
			#tabla_ejecucion
			#refresca_historico_ejecucion # Refresca variables globales de impirmir el historico de la barra de ejecuion
			

			#refresca_tiempos_formula

			termina_procesos
			#actualiza_estados_buffer


			#tabla_ejecucion


			refrescar_deadlock

			refresca_particiones
			
				
			
			calcular_rr_ventana 1
			
			
			primero_exec=0
			for ((i=0; i<$num_proc; i++))
			do
				if [[ $primero_exec == 0 && ( ${ESTADO[$i]} == "En Memoria" || ${ESTADO[$i]} == "En Pausa" ) ]];then
					primero_exec=1
					ch_estado $i 3 "main algoritmo"

				fi
			
			done
			gl_cambio_de_estado=1
			corrige_estados_ejecucion

			#if [[ $proc_rr -gt -1  ]];
			#then
			#	if [[  $proc_rr -ne 0 && $proc_rr -ne 5 ]];
			#	then
			#		echo "$proc_rr"
			#		echo "canalla"
			#		ch_estado $proc_rr 3 "main algoritmo"
			#		gl_proc_ejec=$proc_rr
			#		gl_cambio_de_estado=1
			#		corrige_estados_ejecucion
					
				
			#	fi
			#fi
			
			
			#ejecuta_rr_iteracion  ## Revisar
			
			#ejecuta_segun_ventana
			

			
			
		else
			ch_estado $proc_rr 3 "anticipa_sig_estado" # a ejecutar
			gl_proc_ejec=$proc_rr

			gl_quantum_restante=$quantum 
			gl_medio_quantum=0
			
			corrige_estado_especial
			# Llama aqui para asegurarse que no existan mas de uno en ejecucion, haciendo caso siempre a los punteros de ejecucion de la ventana
			corrige_estados_ejecucion
			refresca_particiones
			calcular_rr_ventana
			
			
		fi
		

		
	fi
}



mostrar_menu_tipo_ejecucion_algoritmo(){
	clear
	imprime_cabecera
	#Antes de ejcutar el algoritmo tenemos que pedir el tipo de ejecucion
		#1->pulsando a enter
		#2->espera en segundos
		#3->automatica
	mostrar_menu_opciones_algoritmo
	read -p " Selecciona una de las siguientes opciones:" optMenuAlgoritmo

	
	# Comporbamos que el numero no esta ente 0 y 6, el numero no esta entre el rango del menu
	while [ $optMenuAlgoritmo -ge 4 ] || [ $optMenuAlgoritmo -le -1 ]  # Lectura erronea
	do
		clear
		imprime_cabecera
		echo " Entrada no válida"
		mostrar_menu_opciones_algoritmo
		read -p " Selecciona una de las siguientes opciones:" optMenuAlgoritmo
			if [ -z $optMenuAlgoritmo ]
			then
				optMenuAlgoritmo="1"
			fi
	done

	if [ $optMenuAlgoritmo == 2 ]
	then
	
		read -p " Introduce los segundos de espera de cada iteración:" tiempo_espera_algoritmo_automatico
		
		if [ -z $tiempo_espera_algoritmo_automatico ]
		then
			tiempo_espera_algoritmo_automatico=1
		fi
	fi


	clear
}

##### FUNCIÓN PRINCIPAL // ALGORITMO #####
## optMenuAlgoritmo
algoritmo() {
	local i
	local backup_momento
	local tiempo_backup
	local resto
	local resta_unidades
	
	
	if [[ $gl_resta_por_quantum == 1 ]];then
		gl_tiempo_restar=$quantum
	fi
	gl_incr_tiempo=1
	#gl_incr_tiempo=$quantum
	
	
	tiempo_transcurrido=0 	# Tiempo de ejecución de los procesos
	gl_procesos_terminados=0 	# Numero de procesos terminados
	procesos_colaauxiliar=0 	# Número de procesos en la cola auxiliar
	siguiente_ejecucion=0
	gl_cadena=" "				 	# Cadena que guarda el gráfico de la evlución (histórico de ejecución)
	gl_cadena_barra=" " 			# Cadena que guarda el gráfico de evolucion pero simple, sin ningún dato añadido, sólo con colores
	gl_cadena_simple=" "
	gl_cadena_nocolor=" "		#PAra el caso de fichero
#	prb=0
	np=0
	proc_memoria=0
	proc_exec=$n_par
	cerr=0
	once=0
	cambio_contexto=0
	
	
	iniciador_de_estados
	
	comprueba_espacio_libre

	#bucle que calcula si algún proceso llega en el instante 0
	inst0=0	
	for(( i=0 ; i < $num_proc ; i++ ))
	do
		if [[  "${T_ENTRADA[$I]}" -lt 1  ]]; then
			((inst0++))
			break
		fi
	done

	if [[ $inst0 -eq 0 ]]; then
		clear
		tabla_ejecucion
		

		if [[ $optMenuAlgoritmo -eq 1 ]]; then
			read -p " <ENTER>"
		fi
		if [[ $optMenuAlgoritmo -eq 2 ]]; then
			sleep $tiempo_espera_algoritmo_automatico
		fi
	fi
	#optMenuAlgoritmo
	gl_quantum_restante=$quantum #Inicializamos quantum restante
	gl_medio_quantum=0

	# Mientras los procesos terminados < procesos totales
	while [ $gl_procesos_terminados -lt $num_proc ]
	do

        
		gl_cambio_proceso=0
        comprueba_tiempo_muerto
		

        if [[ $gl_tiempo_muerto == 1 ]];then
        	((tiempo_transcurrido+=gl_incr_tiempo))
        	((gl_iteracion++))
        	refresca_historico_ejecucion

        	#echo "PASADO TIEMPO MUERTO ${tiempo_transcurrido}"
        	continue
        fi
		# Inicialmente se ejecuta el P0
		if [[ $gl_cambio_de_estado == 1 || $gl_debug == 1 || $debug3 == 1 || $gl_no_saltos == 1 || $tiempo_transcurrido==0 ]];then # En modo debug siempre iprimimos
			clear
		fi


		
		

		gl_revisado_cambio_de_estado=0
		gl_cambio_de_estado=0
		if [[ $debug2 == 1 ]];then
			echo "PRINTGVA0 (Inicio bucle)"
			print_global_vars 1 0 #Primer argumento: Se hará una pausa, Segundo argumento: Será una impresion exhaustiva
		fi
		termina_procesos # Pone en acabado aquellos procesos que lo requieran por no tener ráfaga restante
		
		if [[ $gl_primera_vez != 1 && false ]];then
			tiempo_backup=$tiempo_transcurrido
			((tiempo_transcurrido+=gl_incr_tiempo))
		
			if [[ $debug2 == 1 ]];then
				echo "ITERACION BEGIN AFTER PRIMERA_VEZ:tiempo_transcurrido ha sido incrementado de ${tiempo_backup} ${tiempo_transcurrido} (teniendo en cuenta el quantum)!!!!!!!"
			fi
		fi
		#gl_medio_quantum=$((tiempo_transcurrido % quantum))
		#actualiza_quantum_tiempos 0 # 0: Indica que no tiene en cuenta la consumición de instantes para el cálculo. Modifica las variables globales gl_medio_quantum y gl_quantum_restante
      	actualiza_estados_buffer

		refrescar_deadlock

		refresca_particiones
		
		


		ejecuta_rr_iteracion
		
		ejecuta_segun_ventana

		if [[ $debug2 == 1 ]];then
			echo "PRINTGVA1 (Despues de ejecutar)"
			print_global_vars 1 0
		fi

		calcular_rr_ventana 1
		
		
		if [[ $proc_rr -gt -1 ]];then

			ch_estado $proc_rr 3 "main algoritmo"
			gl_proc_ejec=$proc_rr
		fi

		anticipa_siguiente_estado_ejecucion

		if [[ $gl_cambio_de_estado == 1 || $gl_debug == 1 || $debug3 == 1 || $gl_no_saltos == 1 ]];then # En modo debug siempre iprimimos
			

			tabla_ejecucion

			if [[ $gl_fuerza_iteracion_instante -lt $tiempo_transcurrido ]];then


				if [[ $optMenuAlgoritmo -eq 1 ]]; then
					if [[ $gl_debug == 1 ]];then
						read -p " <ENTER> del bucle"
					else
						
						read -p " <ENTER>"
					fi
				fi

				if [[ $optMenuAlgoritmo -eq 2 ]]; then
					sleep $tiempo_espera_algoritmo_automatico
				fi

			fi
		fi
		#refresca_tiempos #refresca tiempos de espera y ejecucion (TIEMPO_PARADO, TIEMPO_EJEC, T_RETORNO y T_ESPERA)
		


	
		
		gl_primera_vez=0
		
		refresca_procesos_terminados
		refresca_tiempo_final


		
		((gl_iteracion++))
		
		#refresca_tiempos_de_ejecucion # Modifica el array global TIEMPO_EJEC segun los estados
		#refresca_tiempos_de_espera # Modifica el array global TIEMPO_PARADO segun los estados
		refresca_historico_ejecucion # Refresca variables globales de impirmir el historico de la barra de ejecuion
		refresca_tiempos_formula #refresca tiempos de espera y retorno (T_RETORNO y T_ESPERA)

	
		


	done # Bucle de procesos terminados

}

#cabecera del algoritmo en el que nos encontramos
imprime_cabecera() {
	echo -e "\n\n\e[1;35m *********************************************************************************\e[0m"
	echo -e "\e[1;35m *\t\t\t\t\e[1;36mAlgoritmo Round-Robin\e[0m\t\t\t\t\e[1;35m *\e[0m"			
	echo -e "\e[1;35m *\t\t\t\t\e[1;36m  Versión Junio 2022\e[0m \t\t\t\t\e[1;35m *\e[0m"
	echo -e "\e[1;35m *\t\t\t\t\e[1;36mRodrigo Pascual Arnaiz\e[0m \t\t\t\t\e[1;35m *\e[0m"
	if [[ $debug == 1 ]];then
		echo -e "\e[1;35m *\t\t\t\t${bg_color_red}DEBUG MODO 1 ACTIVADO${color_default}\t\t\e[1;35m *${color_default}"
	fi
	if [[ $debug2 == 1 ]];then
		echo -e "\e[1;35m *\t\t\t\t${bg_color_red}DEBUG MODO 2 ACTIVADO${color_default}\t\t\e[1;35m *${color_default}"
	fi
	if [[ $debug3 == 1 ]];then
		echo -e "\e[1;35m *\t\t\t\t${bg_color_red}DEBUG MODO 3 ACTIVADO${color_default}\t\t\e[1;35m *${color_default}"
	fi
	echo -e "\e[1;35m *********************************************************************************\e[0m\n\n\n"
}


print_linea_estados() {
	local i
	if [[ $gl_debug == 1 ]];then
		for ((i=0;i<$num_proc;i++))
		do
			echo -ne "|ST[${i}]=${ESTADO[$i]}"
		done
		echo "|"
	fi
}

print_global_vars() { # Arg1= Force pause of input return, Arg2= Print global arrays too
	local i
	echo "--------------------------------------------------------------"
	echo -e "\tGLOBAL SIMPLE VARIABLES"
	echo "--------------------------------------------------------------"
	echo -e "\tgl_ajuste=${gl_ajuste}"
	echo -e "\tgl_primera_vez=${gl_primera_vez}"
	echo -e "\tgl_iteracion=${gl_iteracion}"
	echo -e "\ttiempo_transcurrido=${tiempo_transcurrido}"
	echo -e "\tgl_procesos_terminados=${gl_procesos_terminados}"
	echo -e "\tprocesos_colaauxiliar=${procesos_colaauxiliar}"
	echo -e "\tprocesos_ejecutables=${procesos_ejecutables}"
	echo -e "\tnp=${np}"
	echo -e "\tproc_memoria=${proc_memoria}"
	echo -e "\tn_par=${n_par}"
	echo -e "\tcerr=${cerr}"
	echo -e "\tonce=${once}"
	echo -e "\tcambio_contexto=${cambio_contexto}"
	echo -e "\tnum_proc=${num_proc}"
	
	echo -e "\tproc_elegido=${proc_elegido}"
	echo -e "\tproc_min_rr=${proc_min_rr}"
	echo -e "\tproc_max_rr=${proc_max_rr}"
	echo -e "\tproc_rr=${proc_rr}"
	echo -e "\tgl_nuevo_puntero=${gl_nuevo_puntero}"
	echo -e "\tgl_cambio_de_estado=${gl_cambio_de_estado}"
	echo -e "\tgl_cambio_proceso=${gl_cambio_proceso}"
	echo -e "\tgl_ultimo_proceso_ejecucion=${gl_ultimo_proceso_ejecucion}"
	echo -e "\tgl_uno_en_ejecucion=${gl_uno_en_ejecucion}"
	echo -e "\tgl_primero_en_ejecucion=${gl_primero_en_ejecucion}"
	echo -e "\tgl_uno_ha_terminado=${gl_uno_ha_terminado}"
	echo -e "\tgl_incr_tiempo=${gl_incr_tiempo}"
	echo -e "\tgl_quantum_restante=${gl_quantum_restante}"
	echo -e "\tgl_medio_quantum=${gl_medio_quantum}"
	echo -e "\tgl_proc_ejec=${gl_proc_ejec}"
	echo -e "\tgl_tiemp_restar=${gl_tiempo_restar}"
	echo -e "\tgl_resta_por_quantum=${gl_resta_por_quantum}"
	echo "Bucle principal: ${gl_procesos_terminados}/${num_proc} (proc terminados/num procesos totales)"
	echo "Subbucle RR (Ventana de RR de ejecucion): ${proc_min_rr} - ${proc_max_rr} puntero: ${proc_rr}"

	if [[ $2 == 1 ]];then

		echo "--------------------------------------------------------------"
		echo -e "\tGLOBAL ARRAYS"
		echo "--------------------------------------------------------------"

		var_name="PROCESOS"
		echo -e "\t${var_name}:"
		i=0
		for val in "${PROCESOS[@]}"
		do
	   		echo -e "\t\t${var_name}[$i]=${val}"
	   		((i++))
		done
		var_name="ESTADO"
		echo -e "\t${var_name}:"
		i=0
		for val in "${ESTADO[@]}"
		do
	   		echo -e "\t\t${var_name}[$i]=${val}"
	   		((i++))
		done
		var_name="ESTADOS_ANTERIORES"
		echo -e "\t${var_name}:"
		i=0
		for val in "${ESTADOS_ANTERIORES[@]}"
		do
	   		echo -e "\t\t${var_name}[$i]=${val}"
	   		((i++))
		done
		var_name="TAM_PART -> Tamaño original de las particiones de memoria"
		echo -e "\t${var_name}:"
		i=0
		for val in "${TAM_PART[@]}"
		do
	   		echo -e "\t\t${var_name}[$i]=${val}"
	   		((i++))
		done
		var_name="MEMORIA"
		echo -e "\t${var_name}:"
		i=0
		for val in "${MEMORIA[@]}"
		do
	   		echo -e "\t\t${var_name}[$i]=${val}"
	   		((i++))
		done
		var_name="T_ENTRADA"
		echo -e "\t${var_name}:"
		i=0
		for val in "${T_ENTRADA[@]}"
		do
	   		echo -e "\t\t${var_name}[$i]=${val}"
	   		((i++))
		done
		var_name="EN_ESPERA"
		echo -e "\t${var_name}:"
		i=0
		for val in "${EN_ESPERA[@]}"
		do
	   		echo -e "\t\t${var_name}[$i]=${val}"
	   		((i++))
		done
		var_name="TIEMPO"
		echo -e "\t${var_name}:"
		i=0
		for val in "${TIEMPO[@]}"
		do
	   		echo -e "\t\t${var_name}[$i]=${val}"
	   		((i++))
		done
		var_name="TIEMPO_EJEC"
		echo -e "\t${var_name}:"
		i=0
		for val in "${TIEMPO_EJEC[@]}"
		do
	   		echo -e "\t\t${var_name}[$i]=${val}"
	   		((i++))
		done
		var_name="TIEMPO_PARADO"
		echo -e "\t${var_name}:"
		i=0
		for val in "${TIEMPO_PARADO[@]}"
		do
	   		echo -e "\t\t${var_name}[$i]=${val}"
	   		((i++))
		done
		var_name="T_RETORNO"
		echo -e "\t${var_name}:"
		i=0
		for val in "${T_RETORNO[@]}"
		do
	   		echo -e "\t\t${var_name}[$i]=${val}"
	   		((i++))
		done
		var_name="T_ESPERA"
		echo -e "\t${var_name}:"
		i=0
		for val in "${T_ESPERA[@]}"
		do
	   		echo -e "\t\t${var_name}[$i]=${val}"
	   		((i++))
		done
		var_name="TIEMPO_FIN"
		echo -e "\t${var_name}:"
		i=0
		for val in "${TIEMPO_FIN[@]}"
		do
	   		echo -e "\t\t${var_name}[$i]=${val}"
	   		((i++))
		done
		var_name="PART"
		echo -e "\t${var_name}:"
		i=0
		for val in "${PART[@]}"
		do
	   		echo -e "\t\t${var_name}[$i]=${val}"
	   		((i++))
		done
		var_name="PART_SIZE -> Tamaño actual disponible en las particiones de memoria"
		echo -e "\t${var_name}:"
		i=0
		for val in "${PART_SIZE[@]}"
		do
	   		echo -e "\t\t${var_name}[$i]=${val}"
	   		((i++))
		done
		var_name="PART_PRINT"
		echo -e "\t${var_name}:"
		i=0
		for val in "${PART_PRINT[@]}"
		do
	   		echo -e "\t\t${var_name}[$i]=${val}"
	   		((i++))
		done
		var_name="T_ESPERA"
		echo -e "\t${var_name}:"
		i=0
		for val in "${T_ESPERA[@]}"
		do
	   		echo -e "\t\t${var_name}[$i]=${val}"
	   		((i++))
		done
		var_name="FIN"
		echo -e "\t${var_name}:"
		i=0
		for val in "${FIN[@]}"
		do
	   		echo -e "\t\t${var_name}[$i]=${val}"
	   		((i++))
		done
		var_name="CONTEXTO"
		echo -e "\t${var_name}:"
		i=0
		for val in "${CONTEXTO[@]}"
		do
	   		echo -e "\t\t${var_name}[$i]=${val}"
	   		((i++))
		done

	fi
	if [[ $1 == 1 && $gl_fuerza_iteracion_instante -lt $tiempo_transcurrido ]];then
		read -p " <Enter to continue>"
	fi
}


# Produce una pausa por pantalla para tocar into, pero teniendo en cuenta la global fuera iteracioninstante
pausaConIteraciones() {
	if [[ $gl_fuerza_iteracion_instante -lt $tiempo_transcurrido ]];then
		read -p "$1"
	fi
}


# Inicio del script:
if [ -f archivo.temp ] || [ -f informeRR.txt ] || [ -f informeColor.txt]
then
	rm archivo.temp
	rm informeRR.txt
	rm informeColor.txt
fi
clear
echo "---------------------------------------------------------------------" >> informeRR.txt
echo "|                                                                   |" >> informeRR.txt
echo "|                         INFORME DE PRÁCTICA                       |" >> informeRR.txt
echo "|                         GESTIÓN DE PROCESOS                       |" >> informeRR.txt
echo "|             -------------------------------------------           |" >> informeRR.txt
echo "|     Antiguo alumno:                                               |" >> informeRR.txt
echo "|     Alumno: Mario Juez Gil                                        |" >> informeRR.txt
echo "|     Sistemas Operativos 2º Semestre                               |" >> informeRR.txt
echo "|     Grado en ingeniería informática (2012-2013)                   |" >> informeRR.txt
echo "|             -------------------------------------------           |" >> informeRR.txt
echo "|     Alumno: Omar Santos Bernabe                                   |" >> informeRR.txt
echo "|     Sistemas Operativos 2º Semestre                               |" >> informeRR.txt
echo "|     Grado en ingeniería informática (2014-2015)                   |" >> informeRR.txt
echo "|             -------------------------------------------           |" >> informeRR.txt
echo "|     Nuevos alumnos:                                               |" >> informeRR.txt
echo "|     Alumnos: Alvaro Urdiales Santidrian                           |" >> informeRR.txt
echo "|     Alumnos: Javier Rodriguez Barcenilla                          |" >> informeRR.txt
echo "|     Sistemas Operativos 2º Semestre                               |" >> informeRR.txt
echo "|     Grado en ingeniería informática (2015-2016)                   |" >> informeRR.txt
echo "|             -------------------------------------------           |" >> informeRR.txt
echo "|     Alumno: Sergio Osuna Jimenez                                  |" >> informeRR.txt
echo "|     Sistemas Operativos 2º Semestre                               |" >> informeRR.txt
echo "|     Grado en ingeniería informática (2016-2017)                   |" >> informeRR.txt	
echo "|             -------------------------------------------           |" >> informeRR.txt
echo "|     Alumno: Adrián Gayo Andrés                                    |" >> informeRR.txt
echo "|     Sistemas Operativos 2º Semestre                               |" >> informeRR.txt
echo "|     Grado en ingeniería informática (2019-2020)                   |" >> informeRR.txt	
echo "|                                                                   |" >> informeRR.txt
echo "---------------------------------------------------------------------" >> informeRR.txt
echo "|     Alumno: Rodrigo Pascual Arnaiz                                |" >> informeRR.txt
echo "|     Sistemas Operativos 2º Semestre                               |" >> informeRR.txt
echo "|     Grado en ingeniería informática (2021-2022)                   |" >> informeRR.txt	
echo "|                                                                   |" >> informeRR.txt
echo "---------------------------------------------------------------------" >> informeRR.txt
echo "" >> informeRR.txt
clear
echo "---------------------------------------------------------------------" >> informeColor.txt
echo "|                                                                   |" >> informeColor.txt
echo "|                         INFORME DE PRÁCTICA                       |" >> informeColor.txt
echo "|                         GESTIÓN DE PROCESOS                       |" >> informeColor.txt
echo "|             -------------------------------------------           |" >> informeColor.txt
echo "|     Antiguo alumno:                                               |" >> informeColor.txt
echo "|     Alumno: Mario Juez Gil                                        |" >> informeColor.txt
echo "|     Sistemas Operativos 2º Semestre                               |" >> informeColor.txt
echo "|     Grado en ingeniería informática (2012-2013)                   |" >> informeColor.txt
echo "|             -------------------------------------------           |" >> informeColor.txt
echo "|     Alumno: Omar Santos Bernabe                                   |" >> informeColor.txt
echo "|     Sistemas Operativos 2º Semestre                               |" >> informeColor.txt
echo "|     Grado en ingeniería informática (2014-2015)                   |" >> informeColor.txt
echo "|             -------------------------------------------           |" >> informeColor.txt
echo "|     Nuevos alumnos:                                               |" >> informeColor.txt
echo "|     Alumnos: Alvaro Urdiales Santidrian                           |" >> informeColor.txt
echo "|     Alumnos: Javier Rodriguez Barcenilla                          |" >> informeColor.txt
echo "|     Sistemas Operativos 2º Semestre                               |" >> informeColor.txt
echo "|     Grado en ingeniería informática (2015-2016)                   |" >> informeColor.txt
echo "|             -------------------------------------------           |" >> informeColor.txt
echo "|     Alumno: Sergio Osuna Jimenez                                  |" >> informeColor.txt
echo "|     Sistemas Operativos 2º Semestre                               |" >> informeColor.txt
echo "|     Grado en ingeniería informática (2016-2017)                   |" >> informeColor.txt
echo "|             -------------------------------------------           |" >> informeColor.txt
echo "|     Alumno: Adrián Gayo Andrés                                    |" >> informeColor.txt
echo "|     Sistemas Operativos 2º Semestre                               |" >> informeColor.txt
echo "|     Grado en ingeniería informática (2019-2020)                   |" >> informeColor.txt	
echo "|                                                                   |" >> informeColor.txt
echo "---------------------------------------------------------------------" >> informeColor.txt
echo "|     Alumno: Alumno: Rodrigo Pascual Arnaiz                        |" >> informeColor.txt
echo "|     Sistemas Operativos 2º Semestre                               |" >> informeColor.txt
echo "|     Grado en ingeniería informática (2021-2022)                   |" >> informeColor.txt	
echo "|                                                                   |" >> informeColor.txt
echo "---------------------------------------------------------------------" >> informeColor.txt
echo "" >> informeColor.txt


imprime_cabecera
echo " Selecciona una de las dos opciones (a,b):"
echo " [a] ROUND ROBIN"
echo " [b] ROUND ROBIN VIRTUAL"
read -p " Su selección es:" opcion

echo " Selecciona una de las dos opciones (a,b):" >> informeRR.txt
echo " [a] ROUND ROBIN" >> informeRR.txt
echo " [b] ROUND ROBIN VIRTUAL" >> informeRR.txt
echo " Teclado: $opcion" >> informeRR.txt

echo " Selecciona una de las dos opciones (a,b):" >> informeColor.txt
echo " [a] ROUND ROBIN" >> informeColor.txt
echo " [b] ROUND ROBIN VIRTUAL" >> informeColor.txt
echo " Teclado: $opcion" >> informeColor.txt


while [ -z "${opcion}" -o \( "${opcion}" != "a" -a "${opcion}" != "b" \) ]
do

	clear
	imprime_cabecera
	echo " (Selección vacía o errónea)"
	echo " [a] ROUND ROBIN"
	echo " [b] ROUND ROBIN VIRTUAL"
	read -p " Vuelva a seleccionar una de las dos opciones (a,b):" opcion

	echo " (Selección vacía o errónea)" >> informeRR.txt
	echo " [a] ROUND ROBIN" >> informeRR.txt
	echo " [b] ROUND ROBIN VIRTUAL" >> informeRR.txt
	echo " Teclado: $opcion" >> informeRR.txt

	echo " (Selección vacía o errónea)" >> informeColor.txt
	echo " [a] ROUND ROBIN" >> informeColor.txt
	echo " [b] ROUND ROBIN VIRTUAL" >> informeColor.txt
	echo " Teclado: $opcion" >> informeColor.txt

done


if [ $opcion = "a" ]
	then
	clear
	echo "	> ROUND ROBIN" >> informeRR.txt
	echo "	> ROUND ROBIN" >> informeColor.txt
elif [ $opcion = "b" ]
	then
	clear
	echo "	> ROUND ROBIN VIRTUAL" >> informeRR.txt
	echo "	> ROUND ROBIN VIRTUAL" >> informeColor.txt
fi

#pedir_memoria
imprime_cabecera

pedir_ajuste # Primero hay que seleccionar el tipo de ajuste que se quiere hacer 

lee_datos_menu # Mostrar menu con 6 opciones y leer el dato introducido






if [ ! "$dat_fich" == "s" ]
then
	meterAfichero
	if [ $opcion = "a" ];then #RR
		rm ultimosRR.rr
		cp ultimosRR.txt ultimosRR.rr
		rm ultimosRR.txt
	else #RRV
		rm ultimos RR.rrv
		mv ultimosRR.txt ultimosRR.rrv
	fi
fi
datos_aux



algoritmo
solucion_impresa


# Almacenamos la solución en el informe
echo "		>> Tiempo total de ejecución de los $num_proc procesos: $tiempo_transcurrido" >> informeRR.txt
echo "" >> informeRR.txt
echo "		>> Gráfico de entrada de procesos:" >> informeRR.txt
echo "		$cadena " >> informeRR.txt
echo "" >> informeRR.txt
echo "		>> Tiempo total de ejecución de los $num_proc procesos: $tiempo_transcurrido" >> informeColor.txt
echo "" >> informeColor.txt
echo "		>> Gráfico de entrada de procesos:" >> informeColor.txt
echo "		$cadena " >> informeColor.txt
echo "" >> informeColor.txt

if [ -f log.temp ]
	then
	rm log.temp
fi


read -p " ¿Quieres abrir el informe? ([s],n): " datos
if [ -z "${datos}" ]
	then
	datos="s"
fi
while [ "${datos}" != "s" -a "${datos}" != "n" ]
do
	read -p " Entrada no válida, vuelve a intentarlo. ¿Quieres abrir el informe? ([s],n): " datos
	if [ -z "${datos}" ]
	then
		datos="s"
	fi
done
if [ $datos = "s" ]
then
	if [[ $gl_color == 0 ]];then
		gedit informeRR.txt
	else
		cat informeRR.txt
	fi
fi