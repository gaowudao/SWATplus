      subroutine hmet_soil_init
    
      use constituent_mass_module
      use input_file_module
      use maximum_data_module
 
      character (len=80) :: titldum
      integer :: eof, imax

      eof = 0
      
      !read all export coefficient data
      inquire (file=in_init%hmet_soil, exist=i_exist)
      if (i_exist /= 0 .or. in_init%hmet_soil /= 'null') then
        do
          open (107,file=in_init%hmet_soil)
          read (107,*,iostat=eof) titldum
          if (eof < 0) exit
          imax = 0
          do while (eof == 0)
            read (107,*,iostat=eof) titldum
            if (eof < 0) exit
            imax = imax + 1
          end do
          
          !db_mx% = imax     not defined in db_mx
          
          allocate (hmeti_db(0:imax))
          rewind (107)
          read (107,*) titldum
          
        do ii = 1, imax
          read (107,*,iostat=eof) hmeti_db(ihmeti)%name, (hmeti_db(ihmeti)%hmeti(ihmet),       &
            ihmet = 1, cs_db%num_metals)
          if (eof < 0) exit
        end do
          close (107)
          exit
        end do
      end if
      
      return
      end subroutine hmet_soil_init