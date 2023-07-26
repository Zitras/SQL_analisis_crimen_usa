/*0. Vamos a ver un poco la forma que tiene la BBDD*/
SELECT *
  FROM `map_usa`.`shr76_21` 
 LIMIT 10 ;
/*1. Primero chequeamos las columnas que nos importan*/
SELECT CNTYFIPS, State, Solved, year_crime, Month, ActionType, Situation, VicAge, VicSex, VicRace, VicEthnic, Weapon, Circumstance, Subcircum
  FROM `map_usa`.`shr76_21` 
 WHERE ActionType = "Normal update"
 LIMIT 10 ;

/*2. Vamos a buscar los 5 años con más homicidios*/
SELECT year_crime as Year, COUNT(*) AS total_murders
FROM `map_usa`.`shr76_21`
GROUP BY Year
ORDER BY total_murders DESC
LIMIT 5 ;
#Son 1980, 1991, 1992, 1993 y 1994

/*3. Primero, los 10 estados con menos homicidios, y vamos a crear una view para consultarlo facilmente */
CREATE VIEW low_10 AS 
SELECT State, COUNT(*) AS total_murders
  FROM `map_usa`.`shr76_21`
 GROUP BY State
 ORDER BY total_murders ASC
 LIMIT 10 ;
#Son North Dakota, Vermont, South Dakota, Wyoming, New Hampshire, Montana, Maine, Rhode Island, Idaho y Delaware

/*4. Luego vamos a crear una view con los 10 estados con más homicidios y también creamos una view para que sean fáciles de consultar*/
CREATE VIEW top_10 AS 
SELECT State, COUNT(*) AS total_murders
  FROM `map_usa`.`shr76_21`
 GROUP BY State
 ORDER BY total_murders DESC
 LIMIT 10 ;
#Son California, Texas, New York, FLorida, Illinois, Michigan, Pennsylvania, Georgia, North Carolina y Ohio

/*5. Comprobamos cual es la raza y método de asesinato más común en los estados en los que menos homicidios se cometen*/
SELECT VicRace, Weapon, COUNT(*) as total_asesinatos
  FROM `map_usa`.`shr76_21`
 WHERE State IN (
				 SELECT State
                   FROM low_10
                   )
 GROUP BY VicRace, Weapon 
 ORDER BY COUNT(*) DESC 
 LIMIT 10 ;
 #Con mucho margen, los más asesinados han sido de raza tiroteados con pistolas, casi el doble que la siguiente categoría (blancos por cuchillo)
 
 /*6. ¿Y la raza y método en los estados con más asesinatos*/
SELECT VicRace, Weapon, COUNT(*) as total_asesinatos
  FROM `map_usa`.`shr76_21`
 WHERE State IN (
				 SELECT State
                   FROM top_10
                   )
 GROUP BY VicRace, Weapon 
 ORDER BY COUNT(*) DESC 
 LIMIT 10 ;
 #Aquí más repartidos, encabezados por víctimas de raza negra pero seguido por dos categorías de raza blanca (pistola y cuchillo), que sumadas suman más que los de raza negra
 
 /*8. ¿Cuántos asesinatos por género? */
 SELECT VicSex, COUNT(*) as total_victimas 
   FROM `map_usa`.`shr76_21`
  WHERE VicSex != "Unknown" 
  GROUP BY VicSex
  ORDER BY COUNT(*) DESC ;
  #Hay casi el triple de asesinatos de hombres que de mujeres, pero ojo, muchos de estos pueden estar realizados por otros hombres. Comprobémoslo en la siguiente consulta
  
 /*8. ¿Cuántos asesinatos por alguien de género contrario? */
 SELECT VicSex, OffSex, COUNT(*) as total_victimas , ROUND(AVG(VicAge),1) as media_edad_victimas
   FROM `map_usa`.`shr76_21`
  WHERE VicSex != OffSex AND VicSex != "Unknown" AND OffSex != "Unknown"
  GROUP BY VicSex, OffSex 
  ORDER BY COUNT(*) DESC ;
  #Sorprendentemente para nadie, los hombres asesinan casi al triple de mujeres que al revés, aunque la media de edad de las víctimas es mayor en los asesinatos de hombres a manos de mujeres
  
  /*9. Vamos a crear una tabla en la que se cuenten los años, los asesinatos por año y el aumento o disminución porcentual con respecto al año anterior*/
  CREATE OR REPLACE VIEW y_a AS
  SELECT year_crime as Year, COUNT(*) as total
    FROM `map_usa`.`shr76_21`
   GROUP BY Year ;
   
   SELECT Year,  total,  ROUND(((total - LAG(total) OVER (ORDER BY Year)) / LAG(total) OVER (ORDER BY Year)) * 100, 2)
	                        AS diferencia_porcentual
     FROM y_a
    ORDER BY Year;
    #Vemos un gran aumento en 2020 con respecto a 2019, no queda muy claro por qué, siendo el año de la pandemia. tal vez tenga que ver con la tensión social de USA ese año
    
    /*10. Por último, vamos a unir la tabla de y_a con otra tabla que cuenta los presidentes de USA y sus partidos.*/
    SELECT u.pres_name, u.Party, u.year_begin, u.year_end, SUM(total) as total_asesinatos, ROUND(Sum(total)/(u.year_end - u.year_begin),0) as asesinatos_por_año
      FROM y_a y
      JOIN map_usa.us_presidents u
        ON y.Year BETWEEN u.year_begin AND u.year_end
	 WHERE u.year_begin >=1976 AND u.year_end <=2021
	 GROUP BY u.pres_name, u.Party, u.year_begin, u.year_end 
     ORDER BY asesinatos_por_año DESC ;
     # No hay una tendencia clara 
        
  


/*11 Unamos la tabla de homicidios con la tabla de asesinos en serie que ya hemos limpiado previamente y contamos*/
CREATE VIEW df_final AS
SELECT *
  FROM `map_usa`.`shr76_21` s
  JOIN  map_usa.sk_dt sk
    ON s.State = sk.state1 OR s.State = sk.state2
 WHERE s.year_crime BETWEEN sk.start_crimes AND sk.end_crimes 
   AND (s.Weapon = sk.weapon1 OR s.Weapon = sk.weapon2 OR s.Weapon = sk.weapon3)
   AND s.VicRace = sk.victimrace
   AND s.VicSex = sk.victimsex
   AND s.VicAge BETWEEN sk.victimagemin AND sk.victimagemax 
   AND s.Solved = "No";
 
 SELECT COUNT(*) AS total_matches
   FROM df_final ;
  
/*12 TOP estados con más asesinos en serie*/
CREATE VIEW top_states AS
SELECT State, COUNT(DISTINCT full_name_sk) as total_asesinos
  FROM df_final
 GROUP BY State
 ORDER BY total_asesinos DESC 
 LIMIT 5 ;
  
  
 
 /*13. TOP asesinos con menos coincidencias*/
CREATE VIEW lowest_sk_count AS
SELECT full_name_sk, COUNT(*) as total_coincidencias
  FROM df_final
 GROUP BY full_name_sk
 ORDER BY total_coincidencias ASC
 LIMIT 10 ;

/*15. Matches con esas dos listas*/
SELECT full_name_sk, COUNT(*) AS total_matches
  FROM df_final
 WHERE State NOT IN (
					SELECT State
                      FROM top_states
					)
   AND full_name_sk IN (
					SELECT full_name_sk
                      FROM lowest_sk_count
                    )
 GROUP BY full_name_sk
 ORDER BY total_matches ASC ;
                    
 /*16. Casos de los sospechosos en su área*/

SELECT full_name_sk, CNTYFIPS, State, year_crime, Month , VicAge, VicSex, VicRace, Weapon, Circumstance, Subcircum, Solved, Situation
  FROM df_final
 WHERE full_name_sk IN ("Anthony Sowell" , "Robert Hansen", "Edwin Kaprat" , "william Sapp (serial killer)") 
   AND CNTYFIPS IN ("Hernando, FL", "Anchorage, AK", "Clark, OH", "Cuyahoga, OH") ;


