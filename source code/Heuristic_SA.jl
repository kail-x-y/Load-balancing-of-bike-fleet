#Author: Wissem Ben Marzouk

using Random

function parse_file(filename::String)

    # Open the file and read all lines
    if isfile(filename)
     file = open(filename)
     lines = readlines(file)
     
     # Initialize variables to store information
     n=0
     k = 0
     x = []
     y = []
     nbp = []
     capa = []
     ideal = []
     warehouse = (0, 0)
    
     # Parse each line
     for line in lines
        
        # Check if the line starts with "K"
        if startswith(line, "K")
            # Parse the number after "K" as the capacity of the trailer
            k = parse(Int64, split(line)[2])
        elseif startswith(line, "stations")
            # do nothing and break "if" so that this line doesn't get included in "else" condition
        elseif startswith(line, "name")
             # do nothing and break "if" so that this line doesn't get included in "else" condition
        elseif startswith(line, "#")
             # do nothing and break "if" so that this line doesn't get included in "else" condition
        elseif startswith(line, "warehouse")
            # Parse the line as the warehouse coordinates
            coords = split(line)[2:3]
            warehouse = (parse(Int64, coords[1]), parse(Int64, coords[2]))
        else
            
            tab = split(line, " ")
            push!(x, parse(Int64, tab[2]))
            push!(y, parse(Int64, tab[3]))
            push!(nbp, parse(Int64, tab[4]))
            push!(capa, parse(Int64, tab[5]))
            push!(ideal, parse(Int64, tab[6]))
            
        end
     end
     n=size(x, 1)

     # Close the file
     close(file)

     # Return the parsed information
    
    end
     return n, k, warehouse, x, y, nbp, capa, ideal
end


# Calculate the global imbalance given the current state of the stations
function calc_global_imbalance(nbp_work::Vector{Any},ideal::Vector{Any})

    #Initialize the total imbalance 
    imbalance = 0

    for i in 1:length(nbp_work)

        imbalance += abs(nbp_work[i] - ideal[i])

    end

    return imbalance
end

function perform_tour(tour::Vector{Int64},k::Int64, nbp_work::Vector{Any},ideal::Vector{Any})

    #Copy the nbp variable to another variable 
    #so when we ran the code more than once, we don't change the original nbp variable taken from the instance.
    nbp_cur=copy(nbp_work)

    #Initialize variables
    load = zeros(Int, length(nbp_work)+1)
    drop = zeros(Int, length(nbp_work)+1)

    # Randomise the load on the trailer at the warehouse
    load[1] = rand(0:k)

    
    # Iterate through each station on the tour
    for j in 2:length(nbp_work)+1

        # Calculate the imbalance at the current station
        imbalance = nbp_cur[tour[j-1]] - ideal[tour[j-1]]

        # If the station is too empty, unload bikes from the trailer then update load and nbp
        if imbalance < 0

            drop[j] = min(-imbalance, load[j-1])
           
            load[j] = load[j-1] - drop[j]
            
            nbp_cur[tour[j-1]] += drop[j]
           
        # If the station is too full, load bikes on the trailer then update load and nbp
        elseif imbalance > 0

            drop[j] = min(imbalance, k - load[j-1])
            
            load[j] = load[j-1] + drop[j]
           
            nbp_cur[tour[j-1]] -= drop[j]
            drop[j]=-drop[j]
           
        # If the station is balanced, do nothing
        else

            drop[j] = 0
            
            load[j] = load[j-1]
            
        end

        # We will not set conditions utilizing capa[i] because ideal[i] <= capa[i]
        
    end
    
    return nbp_cur,drop,load
end

function distances(x::Vector{Any}, y::Vector{Any},w::Tuple{Int64, Int64})
    n=size(x, 1)

    d = zeros(Int64, n, n)
    d_war= zeros(Int64, n)
    for i in 1:n
        d_war[i]=round(sqrt((w[1] - x[i])^2 + (w[2] - y[i])^2))
        for j in 1:n
            d[i, j] = round(sqrt((x[i] - x[j])^2 + (y[i] - y[j])^2))
        end
    end
    
    return d, d_war
end
function tour_distance(vec::Vector{Int64},d::Array{Int64,2},d_war::Vector{Int64})

    # distances from warehouse to first and last stations
    distance = d_war[vec[1]] + d_war[vec[end]] 
    
    for i in 1:length(vec)-1

        distance += d[vec[i], vec[i+1]]

    end
    return distance
end

# main function

function simulated_annealing(n::Int64,k::Int64, nbp_work::Vector{Any}
,ideal::Vector{Any},x::Vector{Any}, y::Vector{Any},w::Tuple{Int64, Int64})
    
        # calculate distances
        d ,d_war= distances(x,y,w)

        # Initialize the temperature T to a high value
        T = 100000

        # Initialize the current tour to a random permutation of the stations
        
        tour = shuffle(1:n)

        # Initialize the load, nbp and drop vectors 
        load = zeros(Int, length(n)+1)
        drop = zeros(Int, length(n)+1)
        curr_state = copy(nbp_work)

        # Initialize the current tour imbalance to the total imbalance of the tour
        imbalance_curr =10*calc_global_imbalance(nbp_work, ideal)

        # Initialize the current tour distance to the total distance of the tour
        d_curr=tour_distance(tour,d,d_war)
        
        # Initialize the best tour found so far and the corresponding imbalance, nbp, drop, load and distance
        best_state = copy(curr_state)
        tour_best = tour
        best_drop=copy(drop)
        best_load=copy(load)
        imbalance_best = imbalance_curr
        d_best = d_curr

        # Start a chronometer
        start = time()

        # While the temperature T is above a certain threshold
        while T > 1e-3

            # Generate a new candidate tour by randomly swapping two stations in tour
            i, j = rand(1:n, 2)
            tour_new = copy(tour)
            tour_new[i], tour_new[j] = tour[j], tour[i]
            new_sate,new_drop,new_load=perform_tour(tour_new,k,curr_state,ideal)

            # Calculate the imbalance and distance of the new candidate tour
            imbalance_new = 10*calc_global_imbalance(new_sate, ideal)
            d_new = tour_distance(tour_new,d,d_war)
           
            # Calculate the acceptance probability
            p = exp((imbalance_curr - imbalance_new) / T) * exp((d_curr - d_new) / T)

            # Generate a random number between 0 and 1
            r = rand()

            # If r < p, accept the new candidate tour
            if r < p

                tour = tour_new
                imbalance_curr = imbalance_new
                d_curr = d_new

                # Update the best tour, imbalance, and distance if the new candidate tour is better
                if imbalance_new < imbalance_best || (imbalance_new == imbalance_best && d_new < d_best)
                    best_drop=copy(new_drop)
                    best_load=copy(new_load)
                    tour_best = tour_new
                    imbalance_best = imbalance_new/10
                    d_best = d_new
                    println(" ")
                    println("Hey guess what! we found a local minima ( hope to escape it though ) at the current temperature of ",T,
                    " C° with current imbalance of ",imbalance_best
                    ," and current load 0 = ",best_load[1]," and current total distance of ",d_best)
                end
            end

            # Reduce the temperature T by a small amount
            T *= 0.999
        end

        finish = time()
       println(" ")
       println("We took ",finish-start," seconds to finish.")
       println(" ")
       println("We start our tour with load 0 = ",best_load[1],".")
       println(" ")
       
       for i in 1:n
        
        println("At step ",i," we go to station ",tour_best[i]," we drop ",best_drop[i+1],
        ". After the drop operation the trailer has ",best_load[i+1]," bikes.")
        println(" ")
       end
       
    
       println("The simulated annealing metaheuristic optimization resulted in an overall imbalance of ",imbalance_best,
       ", and total distance of ",d_best,".")

    # Open the file and write the header
    file = open("mini_5_SA.sol", "w")
    write(file, "name mini_5\n")
    write(file, "imbalance $imbalance_best\n")
    write(file, "distance $d_best\n")
    best_loadv=best_load[1]
    write(file, "init_load $best_loadv\n")

    # Write the station header
    write(file, "stations\n")

    j=2
	for i in tour_best
		best_dropv=best_drop[j]
        write(file,"$i $best_dropv\n")
        j+=1        	
	end
	
    # Write the end marker
    write(file, "End\n")

    # Close the file
    close(file)
     
end
