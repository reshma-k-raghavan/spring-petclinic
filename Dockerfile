# inherit from an image
# FROM eclipse-temurin:17-jdk-jammy
FROM eclipse-temurin:17-jdk-jammy as base

# set image workdir, in order to specify relaative path in further command
WORKDIR /app

# Copy the folder D:\workspace\docker\spring-petclinic\.mvn\ to .mvn folder in the image.
COPY .mvn/ .mvn

# copy the files .mvnw and pom.xml files from project folder in to the /app folder in the image
COPY mvnw pom.xml ./

# run the mvn wrapper command to download the dependencies into the image
RUN ./mvnw dependency:resolve

# copy src folder to the app
COPY src ./src

# Run the Spring Boot command to launch the app. Connect to in-memory H2 database
# CMD ["./mvnw", "spring-boot:run"]

# Run the Spring Boot command to launch the app. Connect to mysql database using a profile
# CMD ["./mvnw", "spring-boot:run", "-Dspring-boot.run.profiles=mysql"]

# Add a new build stage labelled 'test'
FROM base as test
# CMD [ "./mvnw", "test" ]
RUN [ "./mvnw", "test" ]
#              RUN executes tests while building the image file. It adds a new layer and runs it.
#              CMD executes test when running the container


# Add a new build stage labelled 'development'. 
# Development image from base image eclipse-temurin:17-jdk-jammy is created. 
# Also run the image by connecting to MySQL image container using the mysql profile. 
# Also attach a debugger to the running java process
#       Doc:
#           Java Debugger JDWP  
#           java -agentlib:jdwp = help     // Load native agent library        
#               server=y                   // JVM will listen for a Debugger to attach to it
#               transport protocol socket connection
#               suspend=n                // If 'y', tell JVM to wait until debugger is attached. If 'n', JVM starts even if debugger is not attached
#               address=8000            // port at which debug socke listens starting JDK 9
#                                       // If address option is not specified, JVM will assign a dynamic port.
#                                       // Listening for transport dt_socket at address: 12345
#               timeout=10000           // To make JVM  exit after 10 sec without any debugger attaching

FROM base as development
CMD ["./mvnw", "spring-boot:run", "-Dspring-boot.run.profiles=mysql", "-Dspring-boot.run.jvmArguments='-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:8000'"]

# In the next build stage, build and package the project into a jar file
FROM base as build
RUN ./mvnw package

# Create a production image from base image
FROM eclipse-temurin:17-jre-jammy as production

# server listens to port 8080
EXPOSE 8080

# copy the build jar file from workdir's target folder to root folder
COPY --from=build /app/target/spring-petclinic-*.jar /spring-petclinic.jar

# Run the jar file in the root folder using -jar command.
# Also set the system property value to a file in the specified path
#           java.security.SecureRandom classes for generating Cryptographically strong random numbers.
#           java.util.Random is not that strong    
#           The file '/dev/./urandom' serves pseudo random numbers          
CMD ["java", "-Djava.security.egd=file:/dev/./urandom", "-jar", "/spring-petclinic.jar"]