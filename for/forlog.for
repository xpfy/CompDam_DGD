
! Info on constructions used here:
! https://software.intel.com/en-us/node/579826
! https://www.pgroup.com/lit/articles/insider/v3n1a3.htm
! http://fortranwiki.org/fortran/show/Object-oriented+programming


Module forlog_Mod
  ! General module for logging information in abaqus subroutines
  ! Using this module exports a variable log to access the module features
  !
  ! The log%level controls the verbosity
  !    level=0  All output is suppressed (including warnings and errors)
  !    level=1  Only issues that terminate the analysis are logged
  ! -> level=2  (Recommended) Issues that may impact the accuracy of the results are logged
  !    level=3  Verbose logging
  !    level=4  Extremely verbose logging for debugging. Generates large logs and increases analysis run time.


  Use VUMATArg_Mod

  ! Definition of l
  Type forlog
    Integer :: level
    Type(VUMATArg) :: arg                            ! Enables access to all abaqus arguments
    Integer :: fileUnit                              ! Fortran file unit number for the output generated by forlog
    Character(len=255) :: fileName
    Integer :: format                                ! Specifies log file format (1=Single line, human readable, 10=JSON)
    Logical, Private :: hashPrinted = .FALSE.
  Contains
    Procedure :: init                                ! Initializes the logger
    Procedure :: close
    Procedure :: debug                               ! level=4, Maximum amount of information
    Procedure :: info                                ! level=3, Verbose logging
    Procedure :: warn                                ! level=2, Log issues that may impact accuracy of results
    Procedure :: error                               ! level=1, Log isses that require termination of analysis
  End Type forlog

  Interface str
    Module Procedure str_int, str_double, str_real
  End Interface

  ! For public access to forlog
  Type(forlog), Save, Public :: log


Contains

  ! To create a logger
  Subroutine init(this, level, VUMATArgStruct, format)

    ! Arguments
    Class(forlog), intent(INOUT) :: this
    Integer, intent(IN) :: level                                 ! Any message .LE. to the level specified here is written
    Type(VUMATArg), intent(IN) :: VUMATArgStruct                 ! Enables access to all abaqus arguments
    Integer, intent(IN) :: format                                ! Specifies log file format (1=Single line, human readable, 2=JSON)

    ! Locals
    Integer :: stat, lenOutputDir, lenJobName
    Character(len=256) :: outputDir, jobName, cmd, line

    ! Parameters
    Double Precision :: zero
    Parameter (zero=0.d0)

    ! Initialize class variables
    this%fileUnit = 6
    this%level = level
    this%arg = VUMATArgStruct
    this%format = format

    If (this%format .EQ. 2) Then
      ! Initialize output file
      ! Load the output directory
      CALL VGETOUTDIR(outputDir, lenOutputDir)
      ! Load the job name
      CALL VGETJOBNAME(jobName, lenJobName)

      ! Use a different file unit number
      this%fileUnit = 106

      ! Set the file name
      this%fileName = trim(outputDir) // '\' // trim(jobName) // '_debug.csv'

      ! Open the log file
      open(this%fileUnit, file=trim(this%fileName), position='append', recl=1000)
    End If

    ! Git SHA-1 hash (Replace this with the code version number on release)
    If (this%arg%totalTime .EQ. zero .AND. .NOT. this%hashPrinted) Then
      print *, ''
      print *, ' == CompDam_DGD, version 1.0.1 == '
      print *, ''
      this%hashPrinted = .TRUE.
    End If

    ! Store reference to instance
    log = this
  End Subroutine init


  ! Tidy up
  Subroutine close(this)
    ! Arguments
    Class(forlog) :: this

    close(this%fileUnit)
  End Subroutine close


  ! Sets log%level
  Subroutine setLogLevel(l)

    ! Arguments
    Integer, intent(IN) :: l

    log%level = l

    Return
  End Subroutine setLogLevel


  ! Most verbose logging
  Subroutine debug(this, msg)

    ! Arguments
    Class(forlog), intent(IN) :: this
    Character*(*), intent(IN) :: msg

    If (this%level .GE. 4) Then
      Call writeToLog(this,  ", DEBUG, " // msg)
    End If
  End Subroutine debug


  ! General information (verbose logging)
  Subroutine info(this, msg)

    ! Arguments
    Class(forlog), intent(IN) :: this
    Character*(*), intent(IN) :: msg

    If (this%level .GE. 3) Then
      Call writeToLog(this, ", INFO, " // msg)
    End If
  End Subroutine info


  ! Issues that may impact accuracy of results
  Subroutine warn(this, msg)

    Include 'vaba_param.inc'

    ! Arguments
    Class(forlog), intent(IN) :: this
    Character*(*), intent(IN) :: msg

    ! Locals
    Dimension INTV(1), REALV(1)    ! For abaqus warning messages
    Character*8 CHARV(1)           ! For Abaqus warning messages

    If (this%level .GE. 2) Then
      Call writeToLog(this, ", WARNING, " // msg)
      Call XPLB_ABQERR(-1,msg,INTV,REALV,CHARV)
    End If
  End Subroutine warn


  ! Issues that terminate the analysis
  Subroutine error(this, msg)

    Include 'vaba_param.inc'

    ! Arguments
    Class(forlog), intent(IN) :: this
    Character*(*), intent(IN) :: msg

    ! Locals
    Dimension INTV(1), REALV(1)    ! For abaqus warning messages
    Character*8 CHARV(1)           ! For Abaqus warning messages

    If (this%level .GE. 1) Then
      Call writeToLog(this, ", ERROR, " // msg)
      Call XPLB_ABQERR(-3,msg,INTV,REALV,CHARV)
    End If
  End Subroutine error


  ! Private subroutine for writing records
  Subroutine writeToLog(this, msg)
    ! Arguments
    Class(forlog), intent(IN) :: this
    Character*(*), intent(IN) :: msg

    write(this%fileUnit,*) trim(str_double(this%arg%totalTime)) // msg
  End Subroutine writeToLog


  ! Convert an integer to string
  Character(len=30) function str_int(k)
    integer, intent(in) :: k
    write (str_int, *) k
    str_int = adjustl(str_int)
  End Function str_int


  ! Convert a double to a string
  Character(len=30) Function str_double(k)
    Double Precision, intent(in) :: k
    write (str_double, *) k
    str_double = adjustl(str_double)
  End function str_double


  ! Convert a single to a string
  Character(len=30) Function str_real(k)
    Real, intent(in) :: k
    write (str_real, *) k
    str_real = adjustl(str_real)
  End Function str_real


End Module forlog_Mod
